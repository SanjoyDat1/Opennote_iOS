import SwiftUI

/// Bottom sheet for the + button: Photo Library, Document, Insert from Journal.
struct FeynmanPlusSheet: View {
    var onPhotoLibrary: () -> Void
    var onDocument: () -> Void
    var onInsertFromJournal: () -> Void
    var onInsertFormatting: (() -> Void)? = nil
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    plusRow(icon: "photo.on.rectangle.angled", title: "Photo Library", action: onPhotoLibrary)
                    plusRow(icon: "doc.text", title: "Document", action: onDocument)
                    plusRow(icon: "doc.richtext", title: "Insert from Journal", action: onInsertFromJournal)
                    if let onInsertFormatting {
                        plusRow(icon: "textformat.size", title: "Insert heading / list", action: onInsertFormatting)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                Spacer(minLength: 0)
            }
            .background(Color.opennoteCream)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func plusRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { action() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.opennoteGreen.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
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
}
