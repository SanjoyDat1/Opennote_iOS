import SwiftUI

struct CodeCardBlockView: View {
    let code: String
    let language: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            TextEditor(text: Binding(
                get: { code },
                set: { onUpdate($0) }
            ))
            .focused($focusedBlockId, equals: blockId)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: 80)
        }
    }
}
