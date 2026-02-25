import Foundation
import SwiftData

/// SwiftData model for caching auth user locally.
@Model
final class LocalUser {
    var id: UUID
    var email: String?
    var lastSyncAt: Date?
    
    init(id: UUID, email: String?, lastSyncAt: Date? = nil) {
        self.id = id
        self.email = email
        self.lastSyncAt = lastSyncAt
    }
}
