import Foundation
import UIKit

@Observable
@MainActor
final class ScanSessionModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case enhancing
        case recognizing
        case formatting(progress: Double)
        case reviewing
        case done
        case failed(message: String)
    }

    var phase: Phase = .idle
    var capturedImage: UIImage?
    var rawOCRText: String = ""
    var formattedText: String = ""
    var ocrConfidence: Float = 0.0
    var isDeepScan: Bool = false

    // MARK: - Task Management

    private var scanTask: Task<Void, Never>?

    /// Starts a new scan, cancelling any previous in-flight scan first.
    func startScan(_ images: [UIImage]) {
        scanTask?.cancel()
        scanTask = nil

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runScan(images)
        }
        scanTask = task
    }

    private func runScan(_ images: [UIImage]) async {
        guard let image = images.first else { return }
        guard !Task.isCancelled else { return }

        // Store original only for the "view original" button — released after step 3 starts.
        capturedImage = image
        rawOCRText = ""
        formattedText = ""

        // ── STEP 1: Enhance ──────────────────────────────────────
        phase = .enhancing
        let enhanced = await ImagePreprocessor.enhance(image)
        guard !Task.isCancelled else { return }

        // ── STEP 2: On-device OCR ────────────────────────────────
        phase = .recognizing
        if !isDeepScan {
            let ocrResult = try? await VisionOCRService.recognize(enhanced)
            guard !Task.isCancelled else { return }
            ocrConfidence = ocrResult?.averageConfidence ?? 0
            rawOCRText = ocrResult?.rawText ?? ""
        } else {
            ocrConfidence = 0
            rawOCRText = ""
        }

        // ── STEP 3: GPT-4o Vision ────────────────────────────────
        // The enhanced image is passed to the vision service which immediately
        // downscales + JPEG-encodes it. Release the full-res enhanced copy right
        // after submitting so it doesn't compete with the network response buffer.
        phase = .formatting(progress: 0.0)
        let service = OpenAIVisionService()
        var chunkCount = 0

        let stream = service.formatNote(image: enhanced, rawOCRText: rawOCRText)

        do {
            for try await chunk in stream {
                guard !Task.isCancelled else { return }
                formattedText += chunk
                chunkCount += 1
                let progress = min(Double(chunkCount) / 300.0, 0.95)
                phase = .formatting(progress: progress)
            }
        } catch {
            // If the task was cancelled, suppress the error — the new scan will take over.
            guard !Task.isCancelled else { return }
            phase = .failed(message: error.localizedDescription)
            return
        }

        guard !Task.isCancelled else { return }
        formattedText = Self.polishFormattedText(formattedText)
        phase = .reviewing
        scanTask = nil
    }

    func insertText(into note: inout String, mode: InsertionMode) {
        switch mode {
        case .atCursor(let position):
            let idx = note.index(note.startIndex, offsetBy: position,
                                 limitedBy: note.endIndex) ?? note.endIndex
            note.insert(contentsOf: "\n\n" + formattedText + "\n\n", at: idx)
        case .appendToEnd:
            note += "\n\n" + formattedText
        case .replaceAll:
            note = formattedText
        }
        phase = .done
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.reset()
        }
    }

    func reset() {
        scanTask?.cancel()
        scanTask = nil
        // Explicitly nil the image so UIImage backing store is released immediately —
        // not left alive while the user goes back to the editor and compiles PDF.
        capturedImage = nil
        phase = .idle
        rawOCRText = ""
        formattedText = ""
        ocrConfidence = 0.0
    }

    /// Final cleanup pass on LLM output before display.
    private static func polishFormattedText(_ text: String) -> String {
        let numberedPattern = #"^(\d+)\.\s+"#
        var output: [String] = []
        var previousWasBlank = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                if !previousWasBlank { output.append("") }
                previousWasBlank = true
                continue
            }
            previousWasBlank = false

            var cleaned = line
            if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") || cleaned.hasPrefix("• ") {
                cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else {
                cleaned = cleaned.replacingOccurrences(
                    of: numberedPattern, with: "", options: .regularExpression
                )
            }
            if line.hasPrefix("#") || line == "---" || line == "***" {
                output.append(line)
            } else {
                output.append(cleaned)
            }
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
