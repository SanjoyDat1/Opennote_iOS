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

    // MARK: - LaTeX generation

    /// Converts a scanned image into LaTeX **body** content (no preamble) that can be
    /// inserted directly inside an existing \begin{document}...\end{document} block.
    func formatNoteAsLaTeX(image: UIImage, rawOCRText: String, existingLaTeX: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let base64 = prepareImagePayload(image) else {
                        continuation.finish(throwing: OpenAIVisionError.imagePreparationFailed)
                        return
                    }

                    let systemPrompt = """
                    You are an expert LaTeX typesetter. Convert the handwritten or printed notes \
                    in this image into beautifully formatted LaTeX body content.

                    CRITICAL CONSTRAINTS
                    - Output ONLY valid LaTeX body content — the code that belongs INSIDE a \
                    \\begin{document}...\\end{document} block.
                    - Do NOT output \\documentclass, \\usepackage, \\begin{document}, \
                    \\end{document}, or any preamble commands.
                    - Do NOT add any explanation, introduction, or closing remarks.
                    - Start directly with the first LaTeX content token (e.g. \\section{} or \\noindent).

                    STRUCTURE RULES
                    - Use \\section{} for clear top-level headings or main topic titles.
                    - Use \\subsection{} and \\subsubsection{} for sub-headings.
                    - Use \\textbf{} for bold key terms, definitions, and any text that was \
                    underlined, circled, or starred in the original.
                    - Use \\textit{} for italicized or otherwise emphasized text.
                    - Use \\begin{itemize}...\\end{itemize} for unordered lists.
                    - Use \\begin{enumerate}...\\end{enumerate} for numbered lists.
                    - Use \\medskip or \\bigskip between distinct sections for visual breathing room.
                    - Use \\begin{tcolorbox}[colback=gray!10, colframe=gray!40] for callout boxes \
                    if the notes contain boxed or highlighted definitions (omit if not present).

                    MATH RULES
                    - Use inline math $...$ for all inline expressions, variables, and formulas.
                    - Use \\begin{equation}...\\end{equation} for single important display equations.
                    - Use \\begin{align*}...\\end{align*} for multi-line derivations.
                    - Render fractions with \\frac{}{}, integrals with \\int, sums with \\sum, \
                    Greek letters with their proper commands (\\alpha, \\beta, \\theta, etc.).

                    CODE RULES
                    - Use \\begin{verbatim}...\\end{verbatim} for code blocks.
                    - Use \\texttt{} for inline code or fixed-width identifiers.

                    TABLE RULES
                    - Use \\begin{tabular}{...}...\\end{tabular} inside a \\begin{table}[h!] for tables.
                    - Use \\hline for horizontal rules and \\toprule/\\midrule/\\bottomrule if booktabs \
                    package is implied.

                    CONTENT RULES
                    - Transcribe EVERY SINGLE word visible. Never skip, omit, summarize, or paraphrase.
                    - Preserve the original logical order and visual hierarchy of the notes.
                    - Fix obvious handwriting or OCR recognition errors using context clues.
                    - If text is genuinely illegible, write % [illegible] as a LaTeX comment.
                    - Escape all special characters: & → \\&, % → \\%, $ → \\$, # → \\#, \
                    _ → \\_, { → \\{, } → \\}.
                    """

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
                        Convert everything visible in this image into LaTeX body content. \
                        Transcribe every word and use the appropriate LaTeX environments. \
                        Output ONLY valid LaTeX body content — no preamble, no \\begin{document}.
                        """
                    } else {
                        userInstruction = """
                        Raw OCR (reading aid — trust the image over this):
                        \(rawOCRText)

                        Convert everything visible in this image into LaTeX body content. \
                        Use the OCR text only as a spelling aid; rely on the image for structure. \
                        Output ONLY valid LaTeX body content — no preamble, no \\begin{document}.
                        """
                    }
                    contentBlocks.append(["type": "text", "text": userInstruction])

                    let messages: [[String: Any]] = [
                        ["role": "system", "content": systemPrompt],
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
