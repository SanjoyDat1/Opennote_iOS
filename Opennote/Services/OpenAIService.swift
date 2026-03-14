import Foundation
import UIKit

/// Output format instructions appended to all Feynman system prompts.
private let feynmanOutputFormat = """
Output format: Use clean, readable plain text. Use standard Unicode characters (e.g. á not &aacute;). For dashes use hyphen-minus (-) not em-dash. For quotes use straight apostrophe (') and straight double quote ("), not curly/smart quotes. Use markdown sparingly—only **bold** when emphasizing a key term. Avoid excessive formatting. Write in clear, natural language.
"""

@Observable
final class OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = URL(string: "https://api.openai.com/v1")!

    var isConfigured: Bool {
        !OpenAIConfig.apiKey.isEmpty && OpenAIConfig.apiKey != "YOUR_OPENAI_API_KEY"
    }

    /// Stream a chat completion. Yields text deltas as they arrive.
    /// When mode is provided, its systemPrompt is used as the primary instruction.
    func streamChat(
        messages: [[String: String]],
        systemContext: String,
        mode: FeynmanMode = .explain
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appending(path: "chat/completions")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let systemContent = mode.systemPrompt + "\n\n" + feynmanOutputFormat + "\n\n---\nCurrent note context (Markdown):\n\n" + systemContext
                    var allMessages: [[String: String]] = [
                        ["role": "system", "content": systemContent]
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

                    var lineBuffer: [UInt8] = []
                    for try await byte in bytes {
                        if byte == 10 { // newline
                            if let line = String(bytes: lineBuffer, encoding: .utf8) {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.hasPrefix("data: ") {
                                    let jsonStr = String(trimmed.dropFirst(6))
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
                            lineBuffer = []
                        } else if byte != 13 { // skip \r
                            lineBuffer.append(byte)
                        }
                    }
                    // Drain any remaining bytes (in case stream ends without newline)
                    if !lineBuffer.isEmpty, let line = String(bytes: lineBuffer, encoding: .utf8) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("data: ") {
                            let jsonStr = String(trimmed.dropFirst(6))
                            if jsonStr != "[DONE]",
                               let data = jsonStr.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let first = choices.first,
                               let delta = first["delta"] as? [String: Any],
                               let content = delta["content"] as? String, !content.isEmpty {
                                continuation.yield(content)
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

    /// Stream chat with optional mode prefix and optional attached image (multimodal).
    func streamChatWithOptions(
        userPrompt: String,
        systemContext: String,
        modePrefix: String? = nil,
        image: UIImage? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appending(path: "chat/completions")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let systemContent: String
                    if let modePrompt = modePrefix, !modePrompt.isEmpty {
                        systemContent = modePrompt + "\n\n" + feynmanOutputFormat + "\n\n---\nCurrent note context (Markdown):\n\n" + systemContext
                    } else {
                        systemContent = FeynmanMode.explain.systemPrompt + "\n\n" + feynmanOutputFormat + "\n\n---\nCurrent note context (Markdown):\n\n" + systemContext
                    }

                    var userContent: Any
                    if let img = image, let base64 = prepareImageBase64(img) {
                        userContent = [
                            ["type": "text", "text": userPrompt],
                            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"] as [String: Any]]
                        ]
                    } else {
                        userContent = userPrompt
                    }

                    let messages: [[String: Any]] = [
                        ["role": "system", "content": systemContent],
                        ["role": "user", "content": userContent]
                    ]

                    let model = image != nil ? "gpt-4o" : OpenAIConfig.model

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages,
                        "stream": true,
                        "max_tokens": 16384
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: OpenAIError.requestFailed)
                        return
                    }

                    var lineBuffer: [UInt8] = []
                    for try await byte in bytes {
                        if byte == 10 {
                            if let line = String(bytes: lineBuffer, encoding: .utf8) {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.hasPrefix("data: ") {
                                    let jsonStr = String(trimmed.dropFirst(6))
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
                            lineBuffer = []
                        } else if byte != 13 {
                            lineBuffer.append(byte)
                        }
                    }
                    if !lineBuffer.isEmpty, let line = String(bytes: lineBuffer, encoding: .utf8) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("data: ") {
                            let jsonStr = String(trimmed.dropFirst(6))
                            if jsonStr != "[DONE]",
                               let data = jsonStr.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let first = choices.first,
                               let delta = first["delta"] as? [String: Any],
                               let content = delta["content"] as? String, !content.isEmpty {
                                continuation.yield(content)
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

    private func prepareImageBase64(_ image: UIImage) -> String? {
        let maxEdge: CGFloat = 1568
        let size = image.size
        let longerEdge = max(size.width, size.height)
        guard longerEdge > 0 else { return nil }
        let scale = longerEdge > maxEdge ? maxEdge / longerEdge : 1.0
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.82)?.base64EncodedString()
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
            "max_tokens": 16384
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
