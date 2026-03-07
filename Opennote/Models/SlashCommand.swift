import SwiftUI

/// A slash command for the "/" command palette in the journal editor.
struct SlashCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    var assetImage: String? = nil
    let section: SlashCommandSection

    enum SlashCommandSection: String, CaseIterable {
        case formatting = "Formatting"
        case advanced = "Advanced editing"
        case media = "Media"
        case ai = "AI with Feynman"
        case journals = "Journals"
    }
}

extension SlashCommand {
    static let allCommands: [SlashCommand] = [
        // Formatting
        SlashCommand(id: "text", title: "Text", subtitle: nil, icon: "textformat", section: .formatting),
        SlashCommand(id: "h1", title: "Heading 1", subtitle: nil, icon: "textformat.size.larger", section: .formatting),
        SlashCommand(id: "h2", title: "Heading 2", subtitle: nil, icon: "textformat.size", section: .formatting),
        SlashCommand(id: "h3", title: "Heading 3", subtitle: nil, icon: "textformat.size.smaller", section: .formatting),
        SlashCommand(id: "bullet", title: "Bullet list", subtitle: nil, icon: "list.bullet", section: .formatting),
        SlashCommand(id: "numbered", title: "Numbered list", subtitle: nil, icon: "list.number", section: .formatting),
        SlashCommand(id: "checklist", title: "Checklist", subtitle: nil, icon: "checklist", section: .formatting),
        SlashCommand(id: "quote", title: "Quote", subtitle: nil, icon: "quote.closing", section: .formatting),
        SlashCommand(id: "divider", title: "Divider", subtitle: nil, icon: "minus", section: .formatting),
        // Advanced
        SlashCommand(id: "code", title: "Code block", subtitle: "⌘⌥C", icon: "chevron.left.forwardslash.chevron.right", section: .advanced),
        SlashCommand(id: "latex", title: "LaTeX block", subtitle: nil, icon: "function", section: .advanced),
        SlashCommand(id: "graph", title: "Graph (Desmos)", subtitle: nil, icon: "chart.line.uptrend.xyaxis", section: .advanced),
        SlashCommand(id: "math", title: "Math equation", subtitle: nil, icon: "x.squareroot", section: .advanced),
        // Media
        SlashCommand(id: "image", title: "Image", subtitle: nil, icon: "photo", section: .media),
        SlashCommand(id: "photo_to_text", title: "Photo to text", subtitle: "Notes & whiteboards → text", icon: "camera.viewfinder", section: .media),
        // AI
        SlashCommand(id: "ask_feynman", title: "Ask Feynman", subtitle: "Ask anything", icon: "paperplane.fill", assetImage: "logo", section: .ai),
        SlashCommand(id: "flashcards", title: "Make flashcards", subtitle: "AI generates from your notes", icon: "rectangle.stack.fill.badge.plus", section: .ai),
        SlashCommand(id: "practice", title: "Make practice problems", subtitle: "AI generates problems", icon: "questionmark.circle.fill", section: .ai),
        // Journals (placeholders for future)
        SlashCommand(id: "subjournal", title: "Subjournal", subtitle: nil, icon: "book.closed", section: .journals),
        SlashCommand(id: "link_journal", title: "Link to existing journal", subtitle: nil, icon: "link", section: .journals),
    ]

    func matches(filter: String) -> Bool {
        guard !filter.isEmpty else { return true }
        let lower = filter.lowercased()
        return title.lowercased().contains(lower) ||
            section.rawValue.lowercased().contains(lower) ||
            (subtitle?.lowercased().contains(lower) ?? false)
    }
}
