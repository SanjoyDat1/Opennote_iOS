import Foundation
import Supabase

struct SemanticSearchResult: Identifiable {
    let id: UUID
    let similarity: Float
}

/// Semantic search via pgvector cosine similarity.
@Observable
final class SemanticSearchService {
    static let shared = SemanticSearchService()
    
    private let supabase = SupabaseManager.shared
    private let openAI = OpenAIService.shared
    
    /// Search notes by semantic similarity. Returns note IDs ordered by relevance.
    func search(query: String, limit: Int = 5) async throws -> [SemanticSearchResult] {
        guard let client = supabase.client else {
            throw SemanticSearchError.supabaseNotConfigured
        }
        guard openAI.isConfigured else {
            throw SemanticSearchError.openAINotConfigured
        }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let embedding = try await openAI.embed(text: query)
        let embeddingArray = embedding.map { Double($0) }
        
        struct SearchParams: Encodable {
            let p_embedding: [Double]
            let p_match_count: Int
            let p_match_threshold: Double
        }
        
        struct RPCResult: Decodable {
            let note_id: UUID
            let similarity: Double
        }
        
        let params = SearchParams(
            p_embedding: embeddingArray,
            p_match_count: limit,
            p_match_threshold: 0.3
        )
        
        let results: [RPCResult] = try await client.rpc(
            "search_notes_by_embedding",
            params: params
        ).execute().value
        
        return results.map { SemanticSearchResult(id: $0.note_id, similarity: Float($0.similarity)) }
    }
}

enum SemanticSearchError: LocalizedError {
    case supabaseNotConfigured
    case openAINotConfigured
    
    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured: return "Supabase not configured"
        case .openAINotConfigured: return "OpenAI API key not configured"
        }
    }
}
