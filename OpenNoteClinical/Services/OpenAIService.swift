import Foundation

/// Clinical AI Co-Pilot system prompt per spec.
private let systemPrompt = """
You are an embedded Clinical AI Co-Pilot. You have live access to the clinician's notes. Your goal is to assist in data management for cardiology and radiology. If they are documenting an echocardiogram, ECG telemetry, or DICOM imaging results, structure their unstructured data. Ask clarifying questions about missing metrics (e.g., "Did you note the ejection fraction?"). Be concise and clinically focused.
"""

@Observable
final class OpenAIService {
    static let shared = OpenAIService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    
    var isConfigured: Bool {
        !OpenAIConfig.apiKey.isEmpty && OpenAIConfig.apiKey != "YOUR_OPENAI_API_KEY"
    }
    
    /// Stream a chat completion. Yields text deltas as they arrive.
    func streamChat(
        messages: [[String: String]],
        systemContext: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appending(path: "chat/completions")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    var allMessages: [[String: String]] = [
                        ["role": "system", "content": systemPrompt + "\n\n---\nCurrent note context (Markdown):\n\n" + systemContext]
                    ]
                    allMessages.append(contentsOf: messages)
                    
                    let body: [String: Any] = [
                        "model": OpenAIConfig.model,
                        "messages": allMessages.map { ["role": $0["role"]!, "content": $0["content"]!] },
                        "stream": true,
                        "max_tokens": 1024
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: OpenAIError.requestFailed)
                        return
                    }
                    
                    var buffer = ""
                    for try await byte in bytes {
                        buffer.append(Character(Unicode.Scalar(byte)))
                        if buffer.hasSuffix("\n") {
                            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = ""
                            if line.hasPrefix("data: ") {
                                let jsonStr = String(line.dropFirst(6))
                                if jsonStr == "[DONE]" { break }
                                if let data = jsonStr.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let choices = json["choices"] as? [[String: Any]],
                                   let first = choices.first,
                                   let delta = first["delta"] as? [String: Any],
                                   let content = delta["content"] as? String, !content.isEmpty {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Generate embedding for text using text-embedding-3-small (1536 dimensions).
    func embed(text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return [Float](repeating: 0, count: 1536)
        }
        
        let url = baseURL.appending(path: "embeddings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenAIError.requestFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double] else {
            throw OpenAIError.requestFailed
        }
        
        return embedding.map { Float($0) }
    }
    
    /// Non-streaming completion for simple use cases.
    func complete(
        messages: [[String: String]],
        systemContext: String
    ) async throws -> String {
        var result = ""
        for try await delta in streamChat(messages: messages, systemContext: systemContext) {
            result += delta
        }
        return result
    }
}

enum OpenAIError: LocalizedError {
    case requestFailed
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "OpenAI request failed"
        }
    }
}
