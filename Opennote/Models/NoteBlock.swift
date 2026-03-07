import Foundation

struct FlashcardItem: Codable, Hashable, Identifiable {
    var id: UUID
    var front: String
    var back: String

    init(id: UUID = UUID(), front: String, back: String) {
        self.id = id
        self.front = front
        self.back = back
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        front = try c.decodeIfPresent(String.self, forKey: .front) ?? ""
        back = try c.decodeIfPresent(String.self, forKey: .back) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, front, back }
}

struct PracticeProblemItem: Codable, Hashable, Identifiable {
    var id: UUID
    var question: String
    var answer: String

    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        answer = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, question, answer }
}

struct TodoItem: Codable, Hashable {
    var id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }

    enum CodingKeys: String, CodingKey { case id, text, done }
}

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
        case codeCard(language: String, code: String, stdin: String, stdout: String)
        case aiPrompt(command: String, response: String?)
        case graphBlock(expression: String)
        case mathBlock(latex: String)
        case callout(text: String)
        case todo(items: [TodoItem])
        case divider
        case flashcardSet(items: [FlashcardItem])
        case practiceProblems(items: [PracticeProblemItem])

        enum CodingKeys: String, CodingKey {
            case type, level, text, items, language, code, stdin, stdout, command, response, expression, latex, todoItems, flashcardItems, practiceItems
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
                let lang = try c.decode(String.self, forKey: .language)
                let code = try c.decode(String.self, forKey: .code)
                let stdin = try c.decodeIfPresent(String.self, forKey: .stdin) ?? ""
                let stdout = try c.decodeIfPresent(String.self, forKey: .stdout) ?? ""
                self = .codeCard(language: lang, code: code, stdin: stdin, stdout: stdout)
            case "aiPrompt":
                self = .aiPrompt(command: try c.decode(String.self, forKey: .command), response: try c.decodeIfPresent(String.self, forKey: .response))
            case "graphBlock":
                self = .graphBlock(expression: try c.decodeIfPresent(String.self, forKey: .expression) ?? "")
            case "mathBlock":
                self = .mathBlock(latex: try c.decodeIfPresent(String.self, forKey: .latex) ?? "")
            case "callout":
                self = .callout(text: try c.decodeIfPresent(String.self, forKey: .text) ?? "")
            case "todo":
                let decoded = try c.decodeIfPresent([TodoItem].self, forKey: .todoItems)
                self = .todo(items: decoded ?? [TodoItem(text: "", done: false)])
            case "divider":
                self = .divider
            case "flashcardSet":
                let decoded = try c.decodeIfPresent([FlashcardItem].self, forKey: .flashcardItems)
                self = .flashcardSet(items: decoded ?? [])
            case "practiceProblems":
                let decoded = try c.decodeIfPresent([PracticeProblemItem].self, forKey: .practiceItems)
                self = .practiceProblems(items: decoded ?? [])
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
            case .codeCard(let language, let code, let stdin, let stdout):
                try c.encode("codeCard", forKey: .type)
                try c.encode(language, forKey: .language)
                try c.encode(code, forKey: .code)
                try c.encode(stdin, forKey: .stdin)
                try c.encode(stdout, forKey: .stdout)
            case .aiPrompt(let command, let response):
                try c.encode("aiPrompt", forKey: .type)
                try c.encode(command, forKey: .command)
                try c.encodeIfPresent(response, forKey: .response)
            case .graphBlock(let expression):
                try c.encode("graphBlock", forKey: .type)
                try c.encode(expression, forKey: .expression)
            case .mathBlock(let latex):
                try c.encode("mathBlock", forKey: .type)
                try c.encode(latex, forKey: .latex)
            case .callout(let text):
                try c.encode("callout", forKey: .type)
                try c.encode(text, forKey: .text)
            case .todo(let items):
                try c.encode("todo", forKey: .type)
                try c.encode(items, forKey: .todoItems)
            case .divider:
                try c.encode("divider", forKey: .type)
            case .flashcardSet(let items):
                try c.encode("flashcardSet", forKey: .type)
                try c.encode(items, forKey: .flashcardItems)
            case .practiceProblems(let items):
                try c.encode("practiceProblems", forKey: .type)
                try c.encode(items, forKey: .practiceItems)
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
            case .codeCard(let language, let code, _, _):
                return "```\(language)\n\(code)\n```"
            case .aiPrompt(let command, let response):
                var s = "**[AI] \(command)**"
                if let r = response, !r.isEmpty { s += "\n\(r)" }
                return s
            case .graphBlock(let expr):
                return "**Graph:** \(expr)"
            case .mathBlock(let latex):
                return "**Math:** \(latex)"
            case .callout(let text):
                return "> \(text)"
            case .todo(let items):
                return items.map { "[\($0.done ? "x" : " ")] \($0.text)" }.joined(separator: "\n")
            case .divider:
                return "---"
            case .flashcardSet(let items):
                return items.map { "**Q:** \($0.front)\n**A:** \($0.back)" }.joined(separator: "\n\n")
            case .practiceProblems(let items):
                return items.map { "**Q:** \($0.question)\n**A:** \($0.answer)" }.joined(separator: "\n\n")
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }
}
