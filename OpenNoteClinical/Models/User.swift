import Foundation

/// Represents the current authenticated user (from Supabase Auth).
struct User: Identifiable {
    let id: UUID
    let email: String?
    
    init(id: UUID, email: String?) {
        self.id = id
        self.email = email
    }
}
