import Foundation
import SwiftData
import Supabase

@Observable
final class AuthViewModel {
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseManager.shared
    
    var isAuthenticated: Bool { currentUser != nil }
    
    init() {
        Task { await restoreSession() }
    }
    
    @MainActor
    func restoreSession() async {
        guard let client = supabase.client else { return }
        
        do {
            let session = try await client.auth.session
            currentUser = User(
                id: session.user.id,
                email: session.user.email
            )
        } catch {
            currentUser = nil
        }
    }
    
    @MainActor
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            errorMessage = "Supabase not configured. Add your project URL and anon key."
            return
        }
        
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let session = response.session {
                currentUser = User(id: session.user.id, email: session.user.email)
            } else {
                errorMessage = "Check your email to confirm your account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let client = supabase.client else {
            errorMessage = "Supabase not configured. Add your project URL and anon key."
            return
        }
        
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            currentUser = User(id: session.user.id, email: session.user.email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func signOut() async {
        guard let client = supabase.client else { return }
        
        do {
            try await client.auth.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
