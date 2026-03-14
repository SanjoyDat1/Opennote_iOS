import SwiftUI

struct TodoBlockView: View {
    let items: [TodoItem]
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: ([TodoItem]) -> Void
    let onReturnAtLastItem: () -> Void

    @State private var focusedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                emptyPlaceholder
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                itemRow(at: i, item: item)
            }
            if !items.isEmpty && items.last?.text.isEmpty == false {
                addItemRow
            }
        }
        .onAppear {
            if focusedBlockId == blockId, focusedIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedIndex = 0 }
            }
        }
        .onChange(of: focusedBlockId) { _, newId in
            if newId == blockId, focusedIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focusedIndex = max(0, items.count - 1)
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func itemRow(at i: Int, item: TodoItem) -> some View {
        HStack(spacing: 12) {
            checkboxButton(at: i, item: item)
            textField(at: i, item: item)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func checkboxButton(at i: Int, item: TodoItem) -> some View {
        Button {
            Haptics.selection()
            var updated = items
            updated[i].done.toggle()
            onUpdate(updated)
        } label: {
            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(item.done ? Color.opennoteGreen : Color(.systemGray3))
                .animation(.spring(response: 0.2), value: item.done)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func textField(at i: Int, item: TodoItem) -> some View {
        ZStack(alignment: .leading) {
            ListItemField(
                text: textBinding(at: i),
                placeholder: "To-do",
                isFocused: focusedIndex == i,
                onReturn: { handleReturn(at: i) },
                onDeleteWhenEmpty: { handleDeleteEmpty(at: i) },
                onFocusChange: { gained in focusChanged(gained, at: i) }
            )
            .frame(maxWidth: .infinity)
            .opacity(item.done ? 0.45 : 1)

            if item.done {
                Color(.systemGray3)
                    .frame(height: 1.5)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Empty placeholder

    private var emptyPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(Color(.systemGray3))
            Text("Add to-do")
                .font(.system(size: 17))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onUpdate([TodoItem(text: "", done: false)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = 0 }
        }
    }

    // MARK: - Add-item affordance

    private var addItemRow: some View {
        Button {
            appendItem()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(.systemGray4))
                Text("New item")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func textBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { index < items.count ? items[index].text : "" },
            set: { newText in
                guard index < items.count else { return }
                var updated = items
                updated[index].text = newText
                onUpdate(updated)
            }
        )
    }

    private func focusChanged(_ gained: Bool, at index: Int) {
        if gained {
            focusedBlockId = blockId
            focusedIndex = index
        } else if focusedIndex == index {
            focusedIndex = nil
        }
    }

    private func appendItem() {
        var copy = items
        copy.append(TodoItem(text: "", done: false))
        onUpdate(copy)
        let next = copy.count - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
    }

    private func handleReturn(at index: Int) {
        guard index < items.count else { return }
        if items[index].text.isEmpty {
            if items.count > 1 {
                var copy = items
                copy.remove(at: index)
                onUpdate(copy)
            }
            focusedIndex = nil
            onReturnAtLastItem()
        } else {
            var copy = items
            copy.insert(TodoItem(text: "", done: false), at: index + 1)
            onUpdate(copy)
            let next = index + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
        }
    }

    private func handleDeleteEmpty(at index: Int) {
        guard index < items.count, items[index].text.isEmpty else { return }
        if items.count == 1 {
            focusedIndex = nil
            onReturnAtLastItem()
        } else if index > 0 {
            var copy = items
            copy.remove(at: index)
            onUpdate(copy)
            let prev = index - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = prev }
        }
    }
}
