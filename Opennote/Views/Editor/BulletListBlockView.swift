import SwiftUI
import UIKit

// MARK: - BackspaceTextField + ListItemField
// Defined here so all three list block views share one compilation unit.

final class BackspaceTextField: UITextField {
    var onDeleteWhenEmpty: (() -> Void)?
    override func deleteBackward() {
        if (text ?? "").isEmpty { onDeleteWhenEmpty?() } else { super.deleteBackward() }
    }
}

struct ListItemField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "List item"
    var isFocused: Bool
    var onReturn: () -> Void
    var onDeleteWhenEmpty: () -> Void
    var onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> BackspaceTextField {
        let tf = BackspaceTextField()
        tf.delegate = context.coordinator
        tf.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        tf.placeholder = placeholder
        tf.returnKeyType = .next
        tf.autocorrectionType = .yes
        tf.autocapitalizationType = .sentences
        tf.backgroundColor = .clear
        tf.tintColor = UIColor(red: 94/255, green: 158/255, blue: 99/255, alpha: 1)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.onDeleteWhenEmpty = { context.coordinator.parent.onDeleteWhenEmpty() }
        return tf
    }

    func updateUIView(_ tf: BackspaceTextField, context: Context) {
        context.coordinator.parent = self
        tf.placeholder = placeholder
        tf.onDeleteWhenEmpty = { context.coordinator.parent.onDeleteWhenEmpty() }
        if tf.text != text { tf.text = text }
        if isFocused && !tf.isFirstResponder { tf.becomeFirstResponder() }
        else if !isFocused && tf.isFirstResponder { tf.resignFirstResponder() }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ListItemField
        init(_ parent: ListItemField) { self.parent = parent }

        func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let new = (tf.text as NSString? ?? "").replacingCharacters(in: range, with: string)
            DispatchQueue.main.async { self.parent.text = new }
            return true
        }
        func textFieldShouldReturn(_ tf: UITextField) -> Bool { parent.onReturn(); return false }
        func textFieldDidBeginEditing(_ tf: UITextField) { parent.onFocusChange(true) }
        func textFieldDidEndEditing(_ tf: UITextField) { parent.onFocusChange(false) }
    }
}

// MARK: - BulletListBlockView

struct BulletListBlockView: View {
    let items: [String]
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
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

    @ViewBuilder
    private func itemRow(at index: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("•")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
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

    private var addItemRow: some View {
        Button { appendItem() } label: {
            HStack(spacing: 10) {
                Text("•").font(.system(size: 17)).foregroundStyle(Color(.systemGray4))
                Text("New item").font(.system(size: 17)).foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func itemBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < items.count ? items[index] : "" },
            set: { newVal in
                guard index < items.count else { return }
                var copy = items; copy[index] = newVal; onUpdate(copy)
            }
        )
    }

    private func focusChanged(_ gained: Bool, at index: Int) {
        if gained { focusedBlockId = blockId; focusedIndex = index }
        else if focusedIndex == index { focusedIndex = nil }
    }

    private func appendItem() {
        var copy = items; copy.append(""); onUpdate(copy)
        let next = copy.count - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
    }

    private func handleReturn(at index: Int) {
        guard index < items.count else { return }
        if items[index].isEmpty {
            if items.count > 1 { var copy = items; copy.remove(at: index); onUpdate(copy) }
            focusedIndex = nil; onReturnAtLastItem()
        } else {
            var copy = items; copy.insert("", at: index + 1); onUpdate(copy)
            let next = index + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = next }
        }
    }

    private func handleDeleteEmpty(at index: Int) {
        guard index < items.count, items[index].isEmpty else { return }
        if items.count == 1 {
            focusedIndex = nil; onReturnAtLastItem()
        } else if index > 0 {
            var copy = items; copy.remove(at: index); onUpdate(copy)
            let prev = index - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focusedIndex = prev }
        }
    }
}
