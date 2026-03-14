import SwiftUI

/// Modal to select a content chunk from the current journal to include as context for Feynman.
struct FeynmanInsertFromJournalSheet: View {
    let contentChunks: [String]
    var onSelect: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(contentChunks.enumerated()), id: \.offset) { _, chunk in
                    let preview = String(chunk.prefix(200)) + (chunk.count > 200 ? "…" : "")
                    Button {
                        Haptics.selection()
                        onSelect(chunk)
                        onDismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.opennoteGreen)
                                .frame(width: 24, alignment: .center)
                            Text(preview)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Insert from Journal")
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
}
