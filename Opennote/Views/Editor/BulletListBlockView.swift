import SwiftUI

struct BulletListBlockView: View {
    let items: [String]
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: ([String]) -> Void
    let onReturnAtLastItem: () -> Void

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < items.count ? items[index] : "" },
            set: { newValue in
                if index < items.count {
                    var copy = items
                    copy[index] = newValue
                    onUpdate(copy)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    TextField("List item", text: binding(for: index))
                        .focused($focusedBlockId, equals: blockId)
                        .onSubmit {
                            if index == items.count - 1 { onReturnAtLastItem() }
                        }
                        .font(.system(size: 17, design: .default))
                }
                .id(index)
            }
            Button {
                var copy = items
                copy.append("")
                onUpdate(copy)
            } label: {
                HStack(spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("Add item")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15, design: .default))
                }
            }
            .buttonStyle(.plain)
        }
    }
}
