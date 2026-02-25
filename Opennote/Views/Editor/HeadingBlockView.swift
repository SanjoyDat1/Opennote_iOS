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
        case 1: return .system(size: 28, weight: .bold, design: .serif)
        case 2: return .system(size: 22, weight: .semibold, design: .default)
        case 3: return .system(size: 18, weight: .semibold, design: .default)
        default: return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    var body: some View {
        TextField("Heading", text: Binding(get: { text }, set: { onUpdate($0) }))
            .focused($focusedBlockId, equals: blockId)
            .onSubmit(onSubmit)
            .font(font)
    }
}
