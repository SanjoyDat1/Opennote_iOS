import SwiftUI

struct ParagraphBlockView: View {
    let text: String
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    var onSlashTriggered: ((UUID, String) -> Void)? = nil
    var onBackspaceOnEmpty: (() -> Void)? = nil

    @State private var appSettings = AppSettings.shared

    var body: some View {
        ParagraphTextView(
            placeholder: "Type something…",
            text: Binding(
                get: { text },
                set: { onUpdate($0) }
            ),
            isFocused: focusedBlockId == blockId,
            editorFont: appSettings.editorFont,
            onSubmit: onSubmit,
            onSlashTriggered: { filter in
                onSlashTriggered?(blockId, filter)
            },
            onBecameEmpty: onBackspaceOnEmpty,
            onFocusChange: { isFocused in
                if isFocused {
                    focusedBlockId = blockId
                } else if focusedBlockId == blockId {
                    focusedBlockId = nil
                }
            }
        )
        .frame(minHeight: 40)
    }
}
