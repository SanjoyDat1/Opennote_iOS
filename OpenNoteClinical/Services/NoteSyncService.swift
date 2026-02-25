import Foundation
import Supabase

/// Row structure for Supabase notes table.
private struct SupabaseNoteRow: Encodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let blocks_payload: [NoteBlock]
    let updated_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case blocks_payload
        case updated_at
    }
}

/// Syncs notes to Supabase and generates/store embeddings for semantic search.
@Observable
final class NoteSyncService {
    static let shared = NoteSyncService()
    
    private let supabase = SupabaseManager.shared
    private let openAI = OpenAIService.shared
    
    /// Debounce: last sync time per note id
    private var lastSyncTime: [UUID: Date] = [:]
    private let debounceInterval: TimeInterval = 2.0
    
    func syncNote(_ note: Note, markdown: String) async {
        guard let client = supabase.client,
              let userId = note.userId else { return }
        
        let now = Date()
        if let last = lastSyncTime[note.id], now.timeIntervalSince(last) < debounceInterval {
            return
        }
        lastSyncTime[note.id] = now
        
        do {
            let noteId = note.supabaseId ?? note.id
            let row = SupabaseNoteRow(
                id: noteId,
                user_id: userId,
                title: note.title,
                blocks_payload: note.blocks,
                updated_at: note.updatedAt
            )
            
            try await client.from("notes").upsert(row, onConflict: "id").execute()
            
            await MainActor.run { note.supabaseId = noteId }
            
            if openAI.isConfigured, !markdown.trimmingCharacters(in: .whitespaces).isEmpty {
                let embedding = try await openAI.embed(text: markdown)
                let embeddingArray = embedding.map { Double($0) }
                struct EmbeddingParams: Encodable {
                    let p_note_id: String
                    let p_embedding: [Double]
                    let p_content_hash: String?
                }
                let embedParams = EmbeddingParams(
                    p_note_id: noteId.uuidString,
                    p_embedding: embeddingArray,
                    p_content_hash: nil
                )
                _ = try await client.rpc("upsert_note_embedding", params: embedParams).execute()
            }
        } catch {
            print("NoteSyncService: sync failed \(error)")
        }
    }
    
    /// Force sync without debounce (e.g. when closing editor).
    func syncNoteImmediately(_ note: Note, markdown: String) async {
        lastSyncTime[note.id] = nil
        await syncNote(note, markdown: markdown)
    }
}
