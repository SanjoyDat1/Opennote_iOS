import SwiftUI
import PhotosUI
import UIKit

struct PhotoToTextButton: View {
    private let noteText: Binding<String>?
    private let onInsertBlock: ((String, InsertionMode) -> Void)?

    @State private var session = ScanSessionModel()
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var showResult = false
    @State private var showImagePicker = false
    @State private var showSourcePicker = false

    /// Use for string-based editors (e.g. Paper LaTeX editor).
    init(noteText: Binding<String>) {
        self.noteText = noteText
        self.onInsertBlock = nil
    }

    /// Use for block-based editors (e.g. Journal) that insert a new block.
    init(onInsertBlock: @escaping (String, InsertionMode) -> Void) {
        self.noteText = nil
        self.onInsertBlock = onInsertBlock
    }

    var body: some View {
        Button {
            Haptics.impact(.light)
            showSourcePicker = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo to text")
        .sheet(isPresented: $showSourcePicker) {
            PhotoToTextSourceSheet(
                onScanDocument: {
                    showSourcePicker = false
                    showScanner = true
                },
                onChooseFromLibrary: {
                    showSourcePicker = false
                    showImagePicker = true
                },
                onDismiss: {
                    showSourcePicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(
                scannedImages: $scannedImages,
                isPresented: $showScanner
            )
        }
        .onChange(of: scannedImages) { _, newImages in
            guard !newImages.isEmpty else { return }
            showResult = true
            Task {
                await session.handleScannedImages(newImages)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerView(selectedImage: Binding(
                get: { nil },
                set: { img in
                    if let img {
                        scannedImages = [img]
                        showImagePicker = false
                    }
                }
            ))
        }
        .sheet(isPresented: $showResult) {
            ScanResultView(
                session: session,
                onInsert: { text, mode in
                    if let binding = noteText {
                        session.formattedText = text
                        var copy = binding.wrappedValue
                        session.insertText(into: &copy, mode: mode)
                        binding.wrappedValue = copy
                    } else if let block = onInsertBlock {
                        block(text, mode)
                    }
                    Haptics.impact(.medium)
                    showResult = false
                },
                onDismiss: {
                    session.reset()
                    showResult = false
                }
            )
        }
    }
}

// MARK: - PhotoToTextFlowSheet
// Presents the Scan/Library options directly (no button) — use from Feynman bar camera.

struct PhotoToTextFlowSheet: View {
    let onInsertBlock: (String, InsertionMode) -> Void
    let onDismiss: () -> Void

    @State private var session = ScanSessionModel()
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var showResult = false
    @State private var showImagePicker = false

    var body: some View {
        PhotoToTextSourceSheet(
            onScanDocument: {
                showScanner = true
            },
            onChooseFromLibrary: {
                showImagePicker = true
            },
            onDismiss: {
                onDismiss()
            }
        )
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(
                scannedImages: $scannedImages,
                isPresented: $showScanner
            )
        }
        .onChange(of: scannedImages) { _, newImages in
            guard !newImages.isEmpty else { return }
            showResult = true
            Task {
                await session.handleScannedImages(newImages)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerView(selectedImage: Binding(
                get: { nil },
                set: { img in
                    if let img {
                        scannedImages = [img]
                        showImagePicker = false
                    }
                }
            ))
        }
        .sheet(isPresented: $showResult) {
            ScanResultView(
                session: session,
                onInsert: { text, mode in
                    onInsertBlock(text, mode)
                    Haptics.impact(.medium)
                    showResult = false
                },
                onDismiss: {
                    session.reset()
                    showResult = false
                }
            )
        }
    }
}

// MARK: - PhotoToTextSourceSheet

struct PhotoToTextSourceSheet: View {
    var onScanDocument: () -> Void
    var onChooseFromLibrary: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Scan live or pick from your library")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    Button {
                        Haptics.impact(.light)
                        onScanDocument()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.opennoteGreen.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Scan Document")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.opennoteGreen)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.opennoteGreen.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.opennoteLightGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        onChooseFromLibrary()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.opennoteGreen.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Choose from Library")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.opennoteGreen)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.opennoteGreen.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.opennoteLightGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Photo to Text")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - PhotoPickerView

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self else { return }
                if let image = object as? UIImage {
                    Task { @MainActor in
                        self.parent.selectedImage = image
                        // Binding setter already sets showImagePicker = false
                    }
                } else {
                    Task { @MainActor in
                        self.parent.dismiss()
                    }
                }
            }
        }
    }
}
