import SwiftUI

struct ParagraphBlockView: View {
    let text: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    var onSlashTriggered: ((UUID, String) -> Void)? = nil

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                onUpdate(newValue)
                // Trigger when "/" is at start of block or at start of a new line
                let slashAtLineStart = newValue.hasPrefix("/") || newValue.contains("\n/")
                if slashAtLineStart, let trigger = onSlashTriggered {
                    let filter: String
                    if let idx = newValue.lastIndex(of: "/") {
                        let after = newValue.index(after: idx)
                        filter = after < newValue.endIndex ? String(newValue[after...]) : ""
                    } else {
                        filter = ""
                    }
                    trigger(blockId, filter)
                }
            }
        )
    }

    var body: some View {
        TextField("Type something…", text: binding, axis: .vertical)
            .focused($focusedBlockId, equals: blockId)
            .onSubmit(onSubmit)
            .font(.system(size: 17, design: .default))
            .lineLimit(1...100)
            .submitLabel(.done)
    }
}
