import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0 ..< scan.pageCount).map { scan.imageOfPage(at: $0) }
            Task { @MainActor in
                self.parent.scannedImages = pages
                self.parent.isPresented = false
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Task { @MainActor in
                self.parent.isPresented = false
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            Task { @MainActor in
                self.parent.isPresented = false
            }
        }
    }
}
