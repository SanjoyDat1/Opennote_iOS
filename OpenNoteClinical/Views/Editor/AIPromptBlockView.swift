import SwiftUI

/// AI Block: user types a command; streams the response into a new block below.
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
                    .foregroundStyle(.secondary)
                
                TextField("e.g. Simplify this concept", text: Binding(
                    get: { command },
                    set: { onUpdate($0) }
                ))
                .focused($focusedBlockId, equals: blockId)
                .font(.body)
                .disabled(isRunning)
                
                Button {
                    onRun()
                } label: {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accent)
                    }
                }
                .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if let response, !response.isEmpty {
                Text(response)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}
