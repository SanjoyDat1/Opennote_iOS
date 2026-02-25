import SwiftUI

struct ParagraphBlockView: View {
    let text: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        TextField("Type something…", text: Binding(
            get: { text },
            set: { onUpdate($0) }
        ))
        .focused($focusedBlockId, equals: blockId)
        .onSubmit(onSubmit)
        .font(.body)
    }
}
