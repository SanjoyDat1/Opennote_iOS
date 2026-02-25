import SwiftUI

struct AIPromptBlockView: View {
    let command: String
    let response: String?
    let blockId: UUID
    let isRunning: Bool
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    let onRun: () -> Void

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
                Text(response)
                    .font(.system(size: 17, design: .default))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}
