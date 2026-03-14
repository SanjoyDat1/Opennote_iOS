import Foundation
import UIKit

@Observable
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

    func startScan() {
        // Stub - implementation in DocumentScannerView flow
    }

    func handleScannedImages(_ images: [UIImage]) async {
        guard let image = images.first else { return }
        capturedImage = image
        rawOCRText = ""
        formattedText = ""

        // ── STEP 1: Enhance ──────────────────────────────────────
        phase = .enhancing
        let enhanced = await ImagePreprocessor.enhance(image)

        // ── STEP 2: On-device OCR ────────────────────────────────
        phase = .recognizing
        let ocrResult: OCRResult?
        if !isDeepScan {
            ocrResult = try? await VisionOCRService.recognize(enhanced)
            ocrConfidence = ocrResult?.averageConfidence ?? 0
            rawOCRText = ocrResult?.rawText ?? ""
        } else {
            ocrResult = nil
            ocrConfidence = 0
            rawOCRText = ""
        }

        // ── STEP 3: Decide whether to go to OpenAI ─────────────
        // Always go to OpenAI. Vision output is passed as context.
        // (Threshold logic: if you want offline-only fallback in future,
        //  check ocrConfidence >= 0.90 here.)

        phase = .formatting(progress: 0.0)
        let service = OpenAIVisionService()
        var chunkCount = 0

        do {
            for try await chunk in service.formatNote(
                image: enhanced,
                rawOCRText: rawOCRText
            ) {
                formattedText += chunk
                chunkCount += 1
                // Rough progress estimate: assume ~300 chunks for a full page
                let progress = min(Double(chunkCount) / 300.0, 0.95)
                phase = .formatting(progress: progress)
            }
        } catch {
            phase = .failed(message: error.localizedDescription)
            return
        }

        formattedText = Self.polishFormattedText(formattedText)
        phase = .reviewing
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
        // Defer memory cleanup to next run loop tick
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.reset()
        }
    }

    func reset() {
        capturedImage = nil
        phase = .idle
        rawOCRText = ""
        formattedText = ""
        ocrConfidence = 0.0
    }

    private static func polishFormattedText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var output: [String] = []
        var previousWasBlank = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !previousWasBlank {
                    output.append("")
                }
                previousWasBlank = true
                continue
            }

            previousWasBlank = false
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                output.append("• " + String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else {
                output.append(line)
            }
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
