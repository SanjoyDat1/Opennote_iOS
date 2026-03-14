import SwiftUI

/// A slash command for the "/" command palette in the journal editor.
/// Only commands that are 100% implemented are listed here.
struct SlashCommand: Identifiable {
    let id: String
    let title: String
    let icon: String          // SF Symbol name
    var assetImage: String?   // Asset catalog image name (overrides icon)
    let section: SlashCommandSection

    enum SlashCommandSection: String, CaseIterable {
        case basic    = "Basic editing"
        case advanced = "Advanced editing"
        case media    = "Media"
        case ai       = "Build with Feynman"
    }
}

extension SlashCommand {
    static let allCommands: [SlashCommand] = [

        // MARK: Basic editing
        SlashCommand(id: "text",      title: "Text",           icon: "character.textbox",           section: .basic),
        SlashCommand(id: "h1",        title: "Heading 1",      icon: "textformat.size.larger",       section: .basic),
        SlashCommand(id: "h2",        title: "Heading 2",      icon: "textformat.size",              section: .basic),
        SlashCommand(id: "h3",        title: "Heading 3",      icon: "textformat.size.smaller",      section: .basic),
        SlashCommand(id: "bullet",    title: "Bullet list",    icon: "list.bullet",                  section: .basic),
        SlashCommand(id: "numbered",  title: "Numbered list",  icon: "list.number",                  section: .basic),
        SlashCommand(id: "checklist", title: "Checklist",      icon: "checklist",                    section: .basic),
        SlashCommand(id: "quote",     title: "Quote",          icon: "quote.closing",                section: .basic),
        SlashCommand(id: "divider",   title: "Divider",        icon: "minus",                        section: .basic),

        // MARK: Advanced editing
        SlashCommand(id: "code",      title: "Code block",     icon: "chevron.left.forwardslash.chevron.right", section: .advanced),
        SlashCommand(id: "math",      title: "Math / LaTeX",   icon: "x.squareroot",                section: .advanced),
        SlashCommand(id: "graph",     title: "Graph",          icon: "chart.line.uptrend.xyaxis",    section: .advanced),

        // MARK: Media
        SlashCommand(id: "scan_notes",  title: "Scan notes",   icon: "camera.viewfinder",            section: .media),
        SlashCommand(id: "voice_note",  title: "Voice note",   icon: "mic.fill",                     section: .media),

        // MARK: Build with Feynman
        SlashCommand(id: "ask_feynman", title: "Ask Feynman",         icon: "sparkles",    assetImage: "logo", section: .ai),
        SlashCommand(id: "flashcards",  title: "Generate flashcards", icon: "rectangle.stack.fill",           section: .ai),
        SlashCommand(id: "practice",    title: "Practice problems",   icon: "pencil.and.list.clipboard",      section: .ai),
    ]

    /// Returns true when the command title loosely matches a search string.
    func matches(filter: String) -> Bool {
        guard !filter.isEmpty else { return true }
        let q = filter.lowercased()
        return title.lowercased().contains(q) || section.rawValue.lowercased().contains(q)
    }
}
