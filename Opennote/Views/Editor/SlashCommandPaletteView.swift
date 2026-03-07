import SwiftUI

/// Scrollable slash command palette shown when user types "/" in the journal editor.
struct SlashCommandPaletteView: View {
    let filter: String
    let onSelect: (SlashCommand) -> Void

    private var filteredCommands: [(section: SlashCommand.SlashCommandSection, commands: [SlashCommand])] {
        let filtered = SlashCommand.allCommands.filter { $0.matches(filter: filter) }
        let grouped = Dictionary(grouping: filtered, by: { $0.section })
        return SlashCommand.SlashCommandSection.allCases.compactMap { section in
            guard let cmds = grouped[section], !cmds.isEmpty else { return nil }
            return (section, cmds)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Commands")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Type to filter")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredCommands, id: \.section.rawValue) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.section.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(group.commands) { cmd in
                                    Button {
                                        Haptics.selection()
                                        onSelect(cmd)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: cmd.icon)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(cmd.section == .ai ? Color.opennoteGreen : .secondary)
                                                .frame(width: 24, alignment: .center)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cmd.title)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                if let sub = cmd.subtitle {
                                                    Text(sub)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                            if let shortcut = cmd.subtitle, cmd.section == .advanced, shortcut.hasPrefix("⌘") {
                                                Text(shortcut)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.tertiary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 4)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if cmd.id != group.commands.last?.id {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 320)
        }
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
    }
}
