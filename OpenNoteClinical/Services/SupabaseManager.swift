import Foundation
import Supabase

/// Manages the Supabase client singleton. Configure with your project URL and anon key.
@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()
    
    private(set) var client: SupabaseClient?
    
    /// Configure with your Supabase project credentials.
    /// Add these to a Config.plist or use environment variables in production.
    func configure(url: String, anonKey: String) {
        guard let supabaseURL = URL(string: url) else {
            print("SupabaseManager: Invalid URL")
            return
        }
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey)
    }
    
    var isConfigured: Bool { client != nil }
}
