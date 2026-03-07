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
                        "max_tokens": 16384
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

    /// Edit LaTeX content based on user instruction. Returns modified LaTeX or nil on failure.
    func editLaTeX(tex: String, instruction: String) async -> String? {
        guard isConfigured else { return nil }
        let url = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = "You are a LaTeX editor assistant. The user will provide LaTeX source and an instruction. Return ONLY the modified LaTeX source, no explanation. Preserve the full document structure including \\documentclass, preamble, \\begin{document}, \\end{document}."
        let userContent = "Instruction: \(instruction)\n\nCurrent LaTeX:\n```\n\(tex)\n```\n\nReturn the modified LaTeX (full document):"
        let body: [String: Any] = [
            "model": OpenAIConfig.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 16384
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  var content = msg["content"] as? String else { return nil }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.hasPrefix("```") {
                content = content.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                if content.hasSuffix("```") { content = String(content.dropLast(3)) }
            }
            return content.isEmpty ? nil : content
        } catch {
            return nil
        }
    }

    /// Extract text from an image using vision (notes, whiteboards).
    func extractTextFromImage(_ imageData: Data) async -> String? {
        guard isConfigured else { return nil }
        let url = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64 = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Extract all text from this image. The image may be handwritten notes, a whiteboard, or typed text. Return ONLY the extracted text, preserving structure (line breaks, lists). Do not add commentary."],
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]]
            ],
            "max_tokens": 8192
        ] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  var content = msg["content"] as? String else { return nil }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Generate flashcards from note context. Returns JSON array of {front, back}.
    func generateFlashcards(from context: String) async -> [(front: String, back: String)]? {
        guard isConfigured else { return nil }
        let system = "You are a study assistant. Generate 5-8 flashcards from the given notes. Return a JSON array of objects with exactly two keys: \"front\" (question/term) and \"back\" (answer). No other text."
        let user = "Notes:\n\(context)\n\nReturn JSON array of flashcards:"
        let result = await nonStreamingChat(system: system, user: user)
        return parseFlashcardJSON(result)
    }

    /// Generate practice problems from note context.
    func generatePracticeProblems(from context: String) async -> [(question: String, answer: String)]? {
        guard isConfigured else { return nil }
        let system = "You are a study assistant. Generate 3-5 practice problems from the given notes. Return a JSON array of objects with keys \"question\" and \"answer\". No other text."
        let user = "Notes:\n\(context)\n\nReturn JSON array of practice problems:"
        let result = await nonStreamingChat(system: system, user: user)
        return parsePracticeJSON(result)
    }

    private func nonStreamingChat(system: String, user: String) async -> String? {
        let url = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": OpenAIConfig.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": 8192
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  let content = msg["content"] as? String else { return nil }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func parseFlashcardJSON(_ jsonStr: String?) -> [(front: String, back: String)]? {
        guard let str = jsonStr else { return nil }
        var candidates = str
        if let start = candidates.firstIndex(of: "["), let end = candidates.lastIndex(of: "]") {
            candidates = String(candidates[start...end])
        }
        guard let data = candidates.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return arr.compactMap { dict -> (String, String)? in
            guard let f = dict["front"] as? String, let b = dict["back"] as? String else { return nil }
            return (f, b)
        }
    }

    private func parsePracticeJSON(_ jsonStr: String?) -> [(question: String, answer: String)]? {
        guard let str = jsonStr else { return nil }
        var candidates = str
        if let start = candidates.firstIndex(of: "["), let end = candidates.lastIndex(of: "]") {
            candidates = String(candidates[start...end])
        }
        guard let data = candidates.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return arr.compactMap { dict -> (String, String)? in
            guard let q = dict["question"] as? String, let a = dict["answer"] as? String else { return nil }
            return (q, a)
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
