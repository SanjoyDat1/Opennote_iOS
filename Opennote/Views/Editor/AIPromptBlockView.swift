import SwiftUI
import UIKit

struct AIPromptBlockView: View {
    let command: String
    let response: String?
    let blockId: UUID
    let isRunning: Bool
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onRun: () -> Void
    var onCancel: (() -> Void)? = nil
    var onAddToNotes: ((String) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let onClose {
                    Button {
                        Haptics.impact(.light)
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.opennoteGreen)
                TextField("e.g. Explain this concept", text: Binding(get: { command }, set: { onUpdate($0) }))
                    .focused($focusedBlockId, equals: blockId)
                    .font(.system(size: 17, design: .default))
                    .disabled(isRunning)
                Button {
                    if isRunning {
                        onCancel?()
                    } else {
                        onRun()
                    }
                } label: {
                    if isRunning {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.opennoteGreen)
                    }
                }
                .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Color.opennoteLightGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let response, !response.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        markdownText(response)
                            .font(.system(size: 17, design: .default))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(maxHeight: 600)
                    .background(Color(.systemGray6).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.opennoteGreen.opacity(0.3), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Button {
                            onRun()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.opennoteGreen)
                        }
                        .disabled(isRunning)

                        Button {
                            UIPasteboard.general.string = response
                            Haptics.selection()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.opennoteGreen)
                        }
                        .disabled(isRunning)

                        if isRunning {
                            Button {
                                onCancel?()
                            } label: {
                                Label("Cancel", systemImage: "stop.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Button {
                            onAddToNotes?(response)
                        } label: {
                            Label("Insert into journal", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.opennoteGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isRunning)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func markdownText(_ raw: String) -> some View {
        let cleaned = Self.cleanAIOutput(raw)
        if let attributed = try? AttributedString(markdown: cleaned, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(cleaned)
        }
    }

    /// Cleans AI output for proper display: decodes HTML entities, normalizes Unicode.
    private static func cleanAIOutput(_ raw: String) -> String {
        var result = raw
        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&apos;", "'"), ("&nbsp;", " "), ("&aacute;", "á"), ("&eacute;", "é"),
            ("&iacute;", "í"), ("&oacute;", "ó"), ("&uacute;", "ú"), ("&ntilde;", "ñ"),
            ("&Aacute;", "Á"), ("&Eacute;", "É"), ("&copy;", "©"), ("&reg;", "®")
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
