import Foundation

/// A single block in the block-based editor.
struct NoteBlock: Identifiable, Codable, Hashable {
    
    /// Serializes blocks to Markdown for AI context and embeddings.
    static func toMarkdown(_ blocks: [NoteBlock]) -> String {
        blocks.map { block in
            switch block.blockType {
            case .heading(let level, let text):
                let prefix = String(repeating: "#", count: min(level, 6))
                return "\(prefix) \(text)"
            case .paragraph(let text):
                return text.isEmpty ? "" : text
            case .bulletList(let items):
                return items.map { "- \($0)" }.joined(separator: "\n")
            case .numberedList(let items):
                return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .codeCard(let language, let code):
                return "```\(language)\n\(code)\n```"
            case .aiPrompt(let command, let response):
                var s = "**[AI] \(command)**"
                if let r = response, !r.isEmpty { s += "\n\(r)" }
                return s
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }
    var id: UUID
    var orderIndex: Int
    var blockType: BlockType
    
    init(id: UUID = UUID(), orderIndex: Int, blockType: BlockType) {
        self.id = id
        self.orderIndex = orderIndex
        self.blockType = blockType
    }
    
    enum BlockType: Codable, Hashable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bulletList([String])
        case numberedList([String])
        case codeCard(language: String, code: String)
        case aiPrompt(command: String, response: String?)
        
        enum CodingKeys: String, CodingKey {
            case type
            case level
            case text
            case items
            case language
            case code
            case command
            case response
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "heading":
                let level = try container.decode(Int.self, forKey: .level)
                let text = try container.decode(String.self, forKey: .text)
                self = .heading(level: level, text: text)
            case "paragraph":
                let text = try container.decode(String.self, forKey: .text)
                self = .paragraph(text)
            case "bulletList":
                let items = try container.decode([String].self, forKey: .items)
                self = .bulletList(items)
            case "numberedList":
                let items = try container.decode([String].self, forKey: .items)
                self = .numberedList(items)
            case "codeCard":
                let language = try container.decode(String.self, forKey: .language)
                let code = try container.decode(String.self, forKey: .code)
                self = .codeCard(language: language, code: code)
            case "aiPrompt":
                let command = try container.decode(String.self, forKey: .command)
                let response = try container.decodeIfPresent(String.self, forKey: .response)
                self = .aiPrompt(command: command, response: response)
            default:
                self = .paragraph("")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .heading(let level, let text):
                try container.encode("heading", forKey: .type)
                try container.encode(level, forKey: .level)
                try container.encode(text, forKey: .text)
            case .paragraph(let text):
                try container.encode("paragraph", forKey: .type)
                try container.encode(text, forKey: .text)
            case .bulletList(let items):
                try container.encode("bulletList", forKey: .type)
                try container.encode(items, forKey: .items)
            case .numberedList(let items):
                try container.encode("numberedList", forKey: .type)
                try container.encode(items, forKey: .items)
            case .codeCard(let language, let code):
                try container.encode("codeCard", forKey: .type)
                try container.encode(language, forKey: .language)
                try container.encode(code, forKey: .code)
            case .aiPrompt(let command, let response):
                try container.encode("aiPrompt", forKey: .type)
                try container.encode(command, forKey: .command)
                try container.encodeIfPresent(response, forKey: .response)
            }
        }
    }
}
