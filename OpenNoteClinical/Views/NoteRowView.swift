import SwiftUI
import SwiftData

struct NoteRowView: View {
    let note: Note
    
    private var previewText: String {
        switch note.blocks.first?.blockType {
        case .paragraph(let text):
            return text.isEmpty ? "Empty note" : String(text.prefix(80))
        case .heading(_, let text):
            return text.isEmpty ? "Heading" : text
        case .bulletList(let items):
            return items.first ?? "List"
        case .numberedList(let items):
            return items.first ?? "List"
        case .codeCard(_, let code):
            return code.isEmpty ? "Code" : String(code.prefix(40)) + "..."
        case .aiPrompt(let command, _):
            return command.isEmpty ? "Ask AI" : command
        case .none:
            return "Empty note"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Text(note.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
