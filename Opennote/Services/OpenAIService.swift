import Foundation

/// Feynman AI tutor system prompt - Socratic tutor for learning.
private let feynmanSystemPrompt = """
You are Feynman, an AI tutor embedded in the user's notebook. You act as a Socratic tutor: you explain concepts clearly, ask thought-provoking questions, generate practice problems, and help the user understand by teaching (as Feynman would—simply and deeply). You have live access to the user's notes. Use this context to tailor your responses. Be concise, encouraging, and educational. When the user asks a question, explain step-by-step, use analogies when helpful, and suggest related questions they might explore.
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
                        ["role": "system", "content": feynmanSystemPrompt + "\n\n---\nCurrent note context (Markdown):\n\n" + systemContext]
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
}

enum OpenAIError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "OpenAI request failed"
        }
    }
}
