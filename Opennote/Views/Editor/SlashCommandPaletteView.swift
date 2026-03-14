import SwiftUI

// MARK: - Slash Command Palette
//
// Appears as a floating card when the user types "/" in the journal.
// Matches the Notion-style design: section labels → plain rows → icon in gray rounded square.
// Palette shows ONLY when the user types "/" exactly — further typing dismisses it.

struct SlashCommandPaletteView: View {
    let onSelect: (SlashCommand) -> Void
    var onDismiss: () -> Void = {}

    private var groups: [(section: SlashCommand.SlashCommandSection, commands: [SlashCommand])] {
        let all = SlashCommand.allCommands
        return SlashCommand.SlashCommandSection.allCases.compactMap { section in
            let cmds = all.filter { $0.section == section }
            return cmds.isEmpty ? nil : (section, cmds)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                Text("Commands")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptics.impact(.light)
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.systemGray3))
                        .frame(width: 26, height: 26)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.5)

            // ── Scrollable list ──────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.section.rawValue) { group in
                        sectionHeader(group.section.rawValue)
                        ForEach(Array(group.commands.enumerated()), id: \.element.id) { index, cmd in
                            commandRow(cmd)
                            if index < group.commands.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                                    .opacity(0.5)
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .frame(maxHeight: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.13), radius: 20, x: 0, y: 6)
    }

    // MARK: Section header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(.systemGray2))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: Command row
    private func commandRow(_ cmd: SlashCommand) -> some View {
        Button {
            Haptics.selection()
            onSelect(cmd)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            cmd.section == .ai
                                ? Color.opennoteLightGreen.opacity(0.6)
                                : Color(.systemGray5)
                        )
                        .frame(width: 30, height: 30)

                    Group {
                        if let asset = cmd.assetImage {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: cmd.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    cmd.section == .ai
                                        ? Color.opennoteGreen
                                        : Color(.label)
                                )
                        }
                    }
                }

                Text(cmd.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
