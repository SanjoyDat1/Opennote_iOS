import SwiftUI

struct TodoBlockView: View {
    let items: [TodoItem]
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: ([TodoItem]) -> Void
    let onReturnAtLastItem: () -> Void

    private func addNewItemIfNeeded(at i: Int) {
        guard i == items.count - 1 else { return }
        var updated = items
        if updated[i].text.isEmpty {
            if updated.count > 1 {
                updated.remove(at: i)
            }
        } else {
            updated.append(TodoItem(text: "", done: false))
        }
        onUpdate(updated)
        if updated.count > items.count { onReturnAtLastItem() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Add to-do")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                        .onTapGesture {
                            onUpdate([TodoItem(text: "", done: false)])
                        }
                }
                .padding(.vertical, 4)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                HStack(spacing: 12) {
                    Button {
                        Haptics.selection()
                        var updated = items
                        updated[i].done.toggle()
                        onUpdate(updated)
                    } label: {
                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(item.done ? Color.opennoteGreen : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    TextField("To-do", text: Binding(
                        get: { item.text },
                        set: {
                            var updated = items
                            updated[i].text = $0
                            onUpdate(updated)
                        }
                    ))
                    .focused($focusedBlockId, equals: blockId)
                    .font(.system(size: 17))
                    .strikethrough(item.done, color: .secondary)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .onSubmit { addNewItemIfNeeded(at: i) }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
