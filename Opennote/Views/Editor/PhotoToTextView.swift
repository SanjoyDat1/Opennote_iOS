import SwiftUI
import UIKit

/// Sheet for taking a photo and extracting text with AI (notes, whiteboards).
struct PhotoToTextView: View {
    @Binding var isPresented: Bool
    let onInsertText: (String) -> Void

    @State private var showCamera = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var extractedText: String?

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.opennoteGreen)
                    Text("Photo to Text")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                    Text("Take a photo of your notes or whiteboard and Feynman will turn it into text.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)

                Button {
                    Haptics.impact(.light)
                    if isCameraAvailable {
                        showCamera = true
                    } else {
                        errorMessage = "Camera is not available. Use a device with a camera."
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .medium))
                        Text("Take Photo")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color.opennoteGreen)
                        Text("Extracting text...")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else if let err = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let text = extractedText {
                    ScrollView {
                        markdownContent(text)
                            .font(.system(size: 17, design: .default))
                            .lineSpacing(6)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                    .frame(minHeight: 200, maxHeight: 420)
                    .scrollIndicators(.visible)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        Haptics.impact(.light)
                        onInsertText(text)
                        isPresented = false
                    } label: {
                        Text("Insert into Journal")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.opennoteGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.opennoteCream)
            .navigationTitle("Photo to Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in
                showCamera = false
                if let image {
                    Task { await extractText(from: image) }
                }
            }
        }
        .onChange(of: isPresented) { _, presented in
            if !presented {
                showCamera = false
                isLoading = false
                errorMessage = nil
                extractedText = nil
            }
        }
    }

    @ViewBuilder
    private func markdownContent(_ raw: String) -> some View {
        if let attributed = try? AttributedString(markdown: raw) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }

    private func extractText(from image: UIImage) async {
        isLoading = true
        errorMessage = nil
        extractedText = nil

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            await MainActor.run {
                errorMessage = "Could not process image."
                isLoading = false
            }
            return
        }

        let openAI = OpenAIService.shared
        guard openAI.isConfigured else {
            await MainActor.run {
                errorMessage = "Add your OpenAI API key in OpenAIConfig to use Photo to Text."
                isLoading = false
            }
            return
        }

        guard let text = await openAI.extractTextFromImage(data) else {
            await MainActor.run {
                errorMessage = "Could not extract text. Try a clearer photo."
                isLoading = false
            }
            return
        }

        await MainActor.run {
            extractedText = text
            isLoading = false
        }
    }
}

// MARK: - Camera Picker

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage?) -> Void

        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImageCaptured(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageCaptured(nil)
        }
    }
}
