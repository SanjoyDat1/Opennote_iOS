import SwiftUI

// MARK: - Slash Command Palette
//
// Appears as a floating card when the user types "/" in the journal.
// Matches the Notion-style design: section labels → plain rows → icon in gray rounded square.
// Palette shows ONLY when the user types "/" exactly — further typing dismisses it.

struct SlashCommandPaletteView: View {
    let onSelect: (SlashCommand) -> Void

    // Groups by section in the declared order
    private var groups: [(section: SlashCommand.SlashCommandSection, commands: [SlashCommand])] {
        let all = SlashCommand.allCommands
        return SlashCommand.SlashCommandSection.allCases.compactMap { section in
            let cmds = all.filter { $0.section == section }
            return cmds.isEmpty ? nil : (section, cmds)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.section.rawValue) { group in
                    sectionHeader(group.section.rawValue)
                    ForEach(Array(group.commands.enumerated()), id: \.element.id) { index, cmd in
                        commandRow(cmd, isFirst: index == 0 && group.section == .basic)
                        if index < group.commands.count - 1 {
                            Divider()
                                .padding(.leading, 58)
                                .opacity(0.6)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 420)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.13), radius: 24, x: 0, y: 8)
    }

    // MARK: Section header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(.systemGray))
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }

    // MARK: Command row
    private func commandRow(_ cmd: SlashCommand, isFirst: Bool) -> some View {
        Button {
            Haptics.selection()
            onSelect(cmd)
        } label: {
            HStack(spacing: 14) {
                // Icon in rounded-square container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            cmd.section == .ai
                                ? Color.opennoteLightGreen.opacity(0.6)
                                : Color(.systemGray5)
                        )
                        .frame(width: 34, height: 34)

                    Group {
                        if let asset = cmd.assetImage {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: cmd.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(
                                    cmd.section == .ai
                                        ? Color.opennoteGreen
                                        : Color(.label)
                                )
                        }
                    }
                }

                Text(cmd.title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isFirst ? Color(.systemGray6) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
