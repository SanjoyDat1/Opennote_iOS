import SwiftUI

struct HeadingBlockView: View {
    let text: String
    let level: Int
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    
    private var font: Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        default: return .title3
        }
    }
    
    var body: some View {
        TextField("Heading", text: Binding(
            get: { text },
            set: { onUpdate($0) }
        ))
        .focused($focusedBlockId, equals: blockId)
        .onSubmit(onSubmit)
        .font(font)
        .fontWeight(.semibold)
    }
}
