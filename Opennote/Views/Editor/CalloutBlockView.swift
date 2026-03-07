import SwiftUI

struct CalloutBlockView: View {
    let text: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 20))
                .foregroundStyle(Color.opennoteGreen)
            TextEditor(text: Binding(get: { text }, set: { onUpdate($0) }))
                .focused($focusedBlockId, equals: blockId)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 32)
        }
        .padding(14)
        .background(Color.opennoteLightGreen.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.opennoteGreen.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
