import Foundation
import SwiftUI

/// Manages the state and streaming for a Feynman AI conversation.
/// Holds the full message history so the AI has multi-turn context.
@Observable
final class FeynmanConversationViewModel {
    var messages: [FeynmanChatMessage] = []
    var isStreaming: Bool = false
    var selectedMode: FeynmanMode = .explain

    private var streamTask: Task<Void, Never>?

    var isEmpty: Bool { messages.isEmpty }

    // MARK: Send

    @MainActor
    func send(prompt: String, journalContext: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cancel any existing stream before starting a new one
        streamTask?.cancel()

        // Append user message
        messages.append(FeynmanChatMessage(role: .user, content: trimmed))

        // Append streaming placeholder for assistant
        let placeholder = FeynmanChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(placeholder)
        let assistantId = placeholder.id

        isStreaming = true

        // Build history for the API — all confirmed messages (exclude the empty placeholder)
        let history: [[String: String]] = messages
            .dropLast()
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

        streamTask = Task<Void, Never> {
            defer {
                Task { @MainActor in
                    self.isStreaming = false
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        self.messages[idx].isStreaming = false
                    }
                    self.streamTask = nil
                }
            }

            do {
                let stream = OpenAIService.shared.streamChat(
                    messages: history,
                    systemContext: journalContext,
                    mode: selectedMode
                )

                for try await chunk in stream {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                            self.messages[idx].content += chunk
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }),
                       self.messages[idx].content.isEmpty {
                        self.messages[idx].content = "Something went wrong. Please try again."
                    }
                }
            }
        }
    }

    // MARK: Control

    @MainActor
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = messages.indices.last, messages[last].isStreaming {
            messages[last].isStreaming = false
            if messages[last].content.isEmpty {
                messages[last].content = "Generation stopped."
            }
        }
    }

    @MainActor
    func clearHistory() {
        stopStreaming()
        messages = []
    }
}
