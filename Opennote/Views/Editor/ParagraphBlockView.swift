import SwiftUI

struct ParagraphBlockView: View {
    let text: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    var onSlashTriggered: ((UUID, String) -> Void)? = nil

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
