import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var supabaseId: UUID?
    var userId: UUID?
    var title: String
    var blocksPayload: Data? // JSON-encoded array of NoteBlock
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        supabaseId: UUID? = nil,
        userId: UUID? = nil,
        title: String = "Untitled Note",
        blocksPayload: Data? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.userId = userId
        self.title = title
        self.blocksPayload = blocksPayload
        self.updatedAt = updatedAt
    }
    
    /// Decode blocks from JSONB payload
    var blocks: [NoteBlock] {
        get {
            guard let data = blocksPayload else { return [NoteBlock(orderIndex: 0, blockType: .paragraph(""))] }
            return (try? JSONDecoder().decode([NoteBlock].self, from: data)) ?? [NoteBlock(orderIndex: 0, blockType: .paragraph(""))]
        }
        set {
            blocksPayload = try? JSONEncoder().encode(newValue)
        }
    }
}
