import Foundation

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "assistant"
    let content: String
}

@Observable
final class AIAssistantViewModel {
    var messages: [AIChatMessage] = []
    var isLoading = false
    var errorMessage: String?
    
    private let openAI = OpenAIService.shared
    
    /// Called before each send to get fresh note context.
    var contextProvider: () -> String = { "" }
    
    func send(_ userMessage: String) async {
        guard !userMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard openAI.isConfigured else {
            errorMessage = "Add your OpenAI API key in OpenAIConfig.swift"
            return
        }
        
        messages.append(AIChatMessage(role: "user", content: userMessage))
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let systemContext = contextProvider()
        let chatHistory = messages.map { ["role": $0.role, "content": $0.content] }
        
        var assistantContent = ""
        do {
            for try await delta in openAI.streamChat(
                messages: chatHistory,
                systemContext: systemContext
            ) {
                assistantContent += delta
                if let last = messages.last, last.role == "assistant" {
                    messages[messages.count - 1] = AIChatMessage(role: "assistant", content: assistantContent)
                } else {
                    messages.append(AIChatMessage(role: "assistant", content: assistantContent))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clear() {
        messages = []
        errorMessage = nil
    }
}
