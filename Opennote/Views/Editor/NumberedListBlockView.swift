import SwiftUI

struct NumberedListBlockView: View {
    let items: [String]
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: ([String]) -> Void
    let onReturnAtLastItem: () -> Void

    @State private var focusedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                itemRow(at: index)
            }
            if items.last?.isEmpty == false {
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
    private func itemRow(at index: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(index + 1).")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)

            ListItemField(
                text: itemBinding(for: index),
                placeholder: "List item",
                isFocused: focusedIndex == index,
                onReturn: { handleReturn(at: index) },
                onDeleteWhenEmpty: { handleDeleteEmpty(at: index) },
                onFocusChange: { gained in focusChanged(gained, at: index) }
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Add-item affordance

    private var addItemRow: some View {
        Button {
            appendItem()
        } label: {
            HStack(spacing: 8) {
                Text("\(items.count + 1).")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(.systemGray4))
                    .frame(minWidth: 24, alignment: .trailing)
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

    private func itemBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < items.count ? items[index] : "" },
            set: { newVal in
                guard index < items.count else { return }
                var copy = items
                copy[index] = newVal
                onUpdate(copy)
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
        copy.append("")
        onUpdate(copy)
        let next = copy.count - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
    }

    private func handleReturn(at index: Int) {
        guard index < items.count else { return }
        if items[index].isEmpty {
            if items.count > 1 {
                var copy = items
                copy.remove(at: index)
                onUpdate(copy)
            }
            focusedIndex = nil
            onReturnAtLastItem()
        } else {
            var copy = items
            copy.insert("", at: index + 1)
            onUpdate(copy)
            let next = index + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
        }
    }

    private func handleDeleteEmpty(at index: Int) {
        guard index < items.count, items[index].isEmpty else { return }
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
