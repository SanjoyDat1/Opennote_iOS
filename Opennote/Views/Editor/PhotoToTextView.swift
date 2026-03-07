import SwiftUI
import PhotosUI

/// Sheet for picking a photo and extracting text with AI (notes, whiteboards).
struct PhotoToTextView: View {
    @Binding var isPresented: Bool
    let onInsertText: (String) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var extractedText: String?

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

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20, weight: .medium))
                        Text("Choose Photo")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task { await extractText(from: item) }
                }

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
                        Text(text)
                            .font(.system(size: 16, design: .default))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(maxHeight: 240)
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
        .onChange(of: isPresented) { _, presented in
            if !presented {
                selectedItem = nil
                isLoading = false
                errorMessage = nil
                extractedText = nil
            }
        }
    }

    private func extractText(from item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil
        extractedText = nil

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run {
                errorMessage = "Could not load image."
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
