import Foundation
import UIKit
import Vision

struct OCRResult {
    let rawText: String
    let averageConfidence: Float
    let observations: Int
}

enum OCRError: Error {
    case invalidImage
    case noTextFound
    case recognitionFailed(underlying: Error)
}

enum VisionOCRService {
    static func recognize(_ image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.008
            if #available(iOS 16, *) {
                request.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw OCRError.recognitionFailed(underlying: error)
            }

            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                throw OCRError.noTextFound
            }

            // Sort by boundingBox.minY descending (Vision: y=0 at bottom, so descending = top first)
            let sorted = observations.sorted { obs1, obs2 in
                obs1.boundingBox.minY > obs2.boundingBox.minY
            }

            var strings: [String] = []
            var confidences: [Float] = []

            for obs in sorted {
                if let candidate = obs.topCandidates(1).first {
                    strings.append(candidate.string)
                    confidences.append(candidate.confidence)
                }
            }

            let joined = strings.joined(separator: "\n")
            let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

            return OCRResult(
                rawText: joined,
                averageConfidence: avgConfidence,
                observations: observations.count
            )
        }.value
    }
}
