import UIKit
import CoreImage

/// Preprocesses scanned images for optimal OCR and vision model performance.
struct ImagePreprocessor {
    static func enhance(_ image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            guard let ciImage = CIImage(image: image) else {
                print("[ImagePreprocessor] Failed to create CIImage from UIImage")
                return image
            }
            let context = CIContext(options: [.useSoftwareRenderer: false])

            var currentImage = ciImage

            // 1. GRAYSCALE
            if let filter = CIFilter(name: "CIColorMonochrome") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                filter.setValue(CIColor.white, forKey: "inputColor")
                filter.setValue(1.0, forKey: "inputIntensity")
                if let output = filter.outputImage {
                    currentImage = output
                } else {
                    print("[ImagePreprocessor] Grayscale filter failed")
                    return image
                }
            } else {
                print("[ImagePreprocessor] CIColorMonochrome not available")
                return image
            }

            // 2. CONTRAST BOOST
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: "inputContrast")
                filter.setValue(0.05, forKey: "inputBrightness")
                filter.setValue(0.0, forKey: "inputSaturation")
                if let output = filter.outputImage {
                    currentImage = output
                } else {
                    print("[ImagePreprocessor] Contrast filter failed")
                    return image
                }
            } else {
                print("[ImagePreprocessor] CIColorControls not available")
                return image
            }

            // 3. SHARPENING
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                filter.setValue(0.8, forKey: "inputSharpness")
                if let output = filter.outputImage {
                    currentImage = output
                } else {
                    print("[ImagePreprocessor] Sharpen filter failed")
                    return image
                }
            } else {
                print("[ImagePreprocessor] CISharpenLuminance not available")
                return image
            }

            // 4. NOISE REDUCTION
            if let filter = CIFilter(name: "CIMedianFilter") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    currentImage = output
                } else {
                    print("[ImagePreprocessor] Median filter failed")
                    return image
                }
            } else {
                print("[ImagePreprocessor] CIMedianFilter not available")
                return image
            }

            // 5. RENDER TO CGImage
            guard let cgImage = context.createCGImage(currentImage, from: currentImage.extent) else {
                print("[ImagePreprocessor] Failed to render CIImage to CGImage")
                return image
            }
            var resultImage = UIImage(cgImage: cgImage)

            // 6. RESCALE TO OPTIMAL RESOLUTION
            let longerEdge = max(resultImage.size.width, resultImage.size.height)
            let scale: CGFloat
            if longerEdge > 2480 {
                scale = 2480 / longerEdge
            } else if longerEdge < 1200 {
                scale = 1500 / longerEdge
            } else {
                return resultImage
            }
            let newSize = CGSize(
                width: resultImage.size.width * scale,
                height: resultImage.size.height * scale
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resultImage = renderer.image { _ in
                resultImage.draw(in: CGRect(origin: .zero, size: newSize))
            }

            return resultImage
        }.value
    }
}
