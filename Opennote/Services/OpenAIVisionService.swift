import Foundation
import UIKit

/// Handles OpenAI GPT-4o Vision API for converting scanned images to structured Markdown.
/// Image is transmitted to OpenAI API over TLS and not stored or logged locally.
final class OpenAIVisionService {
    private static let systemPrompt = """
    You are a precise handwriting and whiteboard transcription assistant.
    Your job is to convert the content of the provided image into clean,
    well-structured Markdown.

    Rules you must follow without exception:
    - Transcribe ALL visible content. Never summarize, skip, or paraphrase.
    - If you also receive a raw OCR string as context, use it to resolve
      ambiguous characters, but trust the image over the OCR text.
    - Detect visual hierarchy: text that is larger, underlined, circled, or
      written at the top of a section should become a Markdown heading (# or ##).
    - Convert hand-drawn bullet points, dashes, or dots into Markdown list items.
    - Convert numbered lists into proper Markdown numbered lists.
    - If you see drawn checkboxes (empty squares or circles), render them as [ ].
      If they appear checked, render them as [x].
    - If you see anything that looks like code (variable names, equations,
      pseudocode), wrap it in a fenced code block with an appropriate language tag.
    - Preserve blank lines between sections exactly as they appear visually.
    - Fix obvious OCR errors (e.g., "rn" misread as "m") using context.
    - If part of the image is unreadable, insert [illegible] at that position.
    - Return ONLY the Markdown content. No preamble, no explanation,
      no "Here is the transcription:" — just the raw Markdown.
    """

    private func prepareImagePayload(_ image: UIImage) -> String? {
        let maxEdge: CGFloat = 1568
        let size = image.size
        let longerEdge = max(size.width, size.height)
        guard longerEdge > 0 else { return nil }

        let scale: CGFloat
        if longerEdge > maxEdge {
            scale = maxEdge / longerEdge
        } else {
            scale = 1.0
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let jpegData = resized.jpegData(compressionQuality: 0.82) else { return nil }
        return jpegData.base64EncodedString()
    }

    func formatNote(image: UIImage, rawOCRText: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let base64 = prepareImagePayload(image) else {
                        continuation.finish(throwing: OpenAIVisionError.imagePreparationFailed)
                        return
                    }

                    var contentBlocks: [[String: Any]] = [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64)",
                                "detail": "high"
                            ] as [String: Any]
                        ]
                    ]
                    if !rawOCRText.isEmpty {
                        contentBlocks.append([
                            "type": "text",
                            "text": "Raw OCR for reference (trust image over this):\n\(rawOCRText)\n\nPlease transcribe and format this note."
                        ])
                    }

                    let messages: [[String: Any]] = [
                        ["role": "system", "content": Self.systemPrompt],
                        ["role": "user", "content": contentBlocks]
                    ]

                    let body: [String: Any] = [
                        "model": "gpt-4o",
                        "max_tokens": 16384,
                        "stream": true,
                        "messages": messages
                    ]

                    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.finish(throwing: OpenAIVisionError.invalidResponse(statusCode: http.statusCode))
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
                    continuation.finish()
                } catch let error as OpenAIVisionError {
                    continuation.finish(throwing: error)
                } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    continuation.finish(throwing: OpenAIVisionError.networkUnavailable)
                } catch {
                    continuation.finish(throwing: OpenAIVisionError.streamParsingFailed)
                }
            }
        }
    }
}

enum OpenAIVisionError: LocalizedError {
    case imagePreparationFailed
    case invalidResponse(statusCode: Int)
    case streamParsingFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .imagePreparationFailed:
            return "Could not prepare the image for processing."
        case .invalidResponse(let code):
            return "The server returned an error (code \(code))."
        case .streamParsingFailed:
            return "Could not parse the response from the server."
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        }
    }
}
