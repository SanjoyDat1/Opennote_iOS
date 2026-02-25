import Foundation

/// A single block in the Opennote journal block editor.
struct NoteBlock: Identifiable, Codable, Hashable {
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
            case type, level, text, items, language, code, command, response
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "heading":
                self = .heading(level: try c.decode(Int.self, forKey: .level), text: try c.decode(String.self, forKey: .text))
            case "paragraph":
                self = .paragraph(try c.decode(String.self, forKey: .text))
            case "bulletList":
                self = .bulletList(try c.decode([String].self, forKey: .items))
            case "numberedList":
                self = .numberedList(try c.decode([String].self, forKey: .items))
            case "codeCard":
                self = .codeCard(language: try c.decode(String.self, forKey: .language), code: try c.decode(String.self, forKey: .code))
            case "aiPrompt":
                self = .aiPrompt(command: try c.decode(String.self, forKey: .command), response: try c.decodeIfPresent(String.self, forKey: .response))
            default:
                self = .paragraph("")
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .heading(let level, let text):
                try c.encode("heading", forKey: .type)
                try c.encode(level, forKey: .level)
                try c.encode(text, forKey: .text)
            case .paragraph(let text):
                try c.encode("paragraph", forKey: .type)
                try c.encode(text, forKey: .text)
            case .bulletList(let items):
                try c.encode("bulletList", forKey: .type)
                try c.encode(items, forKey: .items)
            case .numberedList(let items):
                try c.encode("numberedList", forKey: .type)
                try c.encode(items, forKey: .items)
            case .codeCard(let language, let code):
                try c.encode("codeCard", forKey: .type)
                try c.encode(language, forKey: .language)
                try c.encode(code, forKey: .code)
            case .aiPrompt(let command, let response):
                try c.encode("aiPrompt", forKey: .type)
                try c.encode(command, forKey: .command)
                try c.encodeIfPresent(response, forKey: .response)
            }
        }
    }
}

extension NoteBlock {
    static func toMarkdown(_ blocks: [NoteBlock]) -> String {
        blocks.map { block in
            switch block.blockType {
            case .heading(let level, let text):
                return String(repeating: "#", count: min(level, 6)) + " " + text
            case .paragraph(let text):
                return text
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
}
