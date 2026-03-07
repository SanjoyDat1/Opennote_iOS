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
                if newValue == "/" || newValue.hasPrefix("/") {
                    let filter = newValue == "/" ? "" : String(newValue.dropFirst())
                    onSlashTriggered?(blockId, filter)
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
