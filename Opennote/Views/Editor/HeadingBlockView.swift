import SwiftUI

struct HeadingBlockView: View {
    let text: String
    let level: Int
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onSubmit: () -> Void
    var onSlashTriggered: ((UUID, String) -> Void)? = nil

    @FocusState private var isFieldFocused: Bool

    private var font: Font {
        switch level {
        case 1: return .system(size: 28, weight: .bold, design: .serif)
        case 2: return .system(size: 22, weight: .semibold, design: .default)
        case 3: return .system(size: 18, weight: .semibold, design: .default)
        default: return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                onUpdate(newValue)
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
        TextField("Heading", text: binding)
            .focused($isFieldFocused)
            .onSubmit(onSubmit)
            .font(font)
            .onChange(of: isFieldFocused) { _, focused in
                if focused { focusedBlockId = blockId }
                else if focusedBlockId == blockId { focusedBlockId = nil }
            }
    }
}
