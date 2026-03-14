import Foundation
import UIKit

/// Handles OpenAI GPT-4o Vision API for converting scanned images to structured Markdown.
/// Image is transmitted to OpenAI API over TLS and not stored or logged locally.
final class OpenAIVisionService {
    private static let systemPrompt = """
    You are an expert note-taking assistant that converts handwritten or printed \
    notes into clean, beautifully structured plain-text notes for a mobile app.

    YOUR GOAL
    Faithfully capture every word the student wrote, then organize it so it reads
    like a polished, professional study note — clear, scannable, and easy to review.

    STRUCTURE RULES
    - If the page has a clear title or subject, render it as: # Title
    - Use ## for major section headings (topics, chapters, big ideas)
    - Use ### for sub-headings (sub-topics, examples, sub-concepts)
    - Use **bold** for key terms, definitions, names, formulas written in words,
      and any text that was underlined, circled, or starred in the original.
    - Write all other content as clean body paragraphs.
    - Separate distinct sections with a single blank line.
    - Use --- only for a clear visual break between completely separate topics on
      the same page (use sparingly — at most once or twice per page).

    CONTENT RULES
    - Transcribe EVERY SINGLE word you can read. Never skip, summarize, abbreviate, or paraphrase.
    - There is NO word limit — output the full page, even if it is very long.
    - Preserve the original logical order and flow of ideas.
    - If the writer used bullets, dashes, or numbered items, convert each item
      into a short, flowing sentence or keep it as its own paragraph.
      Do NOT output bullet points, dashes, or numbered list markers.
    - Fix obvious handwriting or OCR recognition errors using context clues.
    - If any portion is genuinely illegible, write [illegible] at that position.
    - Do NOT output code blocks, LaTeX, or equations (text-only beta).
    - Do NOT add any content that was not in the original notes.

    OUTPUT FORMAT
    - Return ONLY the formatted note text — no preamble, no explanation,
      no "Here is the transcription", no closing remarks.
    - Start immediately with the note content.
    """

    private func prepareImagePayload(_ image: UIImage) -> String? {
        // GPT-4o "high" detail tiles at 512×512 and supports up to 2048px per edge.
        // Staying at 2048 gives maximum resolution without exceeding the model's tile budget.
        let maxEdge: CGFloat = 2048
        let size = image.size
        let longerEdge = max(size.width, size.height)
        guard longerEdge > 0 else { return nil }

        let scale: CGFloat = longerEdge > maxEdge ? maxEdge / longerEdge : 1.0

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // 0.92 quality preserves fine handwriting strokes without excessive file size
        guard let jpegData = resized.jpegData(compressionQuality: 0.92) else { return nil }
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
                    let userInstruction: String
                    if rawOCRText.isEmpty {
                        userInstruction = """
                        Transcribe EVERY word visible in this image — top to bottom, left to right. \
                        Do not skip, omit, or summarize any text regardless of how much there is. \
                        There is no word limit. Output everything you can read.
                        """
                    } else {
                        userInstruction = """
                        Raw OCR (use as a reading aid — trust the image over this):
                        \(rawOCRText)

                        Transcribe EVERY word visible in this image — top to bottom, left to right. \
                        Do not skip, omit, or summarize any text regardless of how much there is. \
                        There is no word limit. Output everything you can read.
                        """
                    }
                    contentBlocks.append([
                        "type": "text",
                        "text": userInstruction
                    ])

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
