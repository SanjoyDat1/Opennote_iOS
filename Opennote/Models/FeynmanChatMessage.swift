import Foundation

/// A single message in a Feynman AI conversation.
struct FeynmanChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    var isStreaming: Bool
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, content: String = "", isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
        self.timestamp = Date()
    }

    enum Role: Equatable {
        case user
        case assistant
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}
