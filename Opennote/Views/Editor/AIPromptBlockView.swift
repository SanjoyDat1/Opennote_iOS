import SwiftUI

struct AIPromptBlockView: View {
    let command: String
    let response: String?
    let blockId: UUID
    let isRunning: Bool
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onRun: () -> Void
    var onAddToNotes: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.opennoteGreen)
                TextField("e.g. Explain this concept", text: Binding(get: { command }, set: { onUpdate($0) }))
                    .focused($focusedBlockId, equals: blockId)
                    .font(.system(size: 17, design: .default))
                    .disabled(isRunning)
                Button {
                    onRun()
                } label: {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.opennoteGreen)
                    }
                }
                .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
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
                            onAddToNotes?(response)
                        } label: {
                            Label("Add to notes", systemImage: "plus.circle.fill")
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
        if let attributed = try? AttributedString(markdown: raw) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }
}
