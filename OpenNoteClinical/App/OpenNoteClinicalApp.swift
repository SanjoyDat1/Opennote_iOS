import SwiftUI
import SwiftData

@main
struct OpenNoteClinicalApp: App {
    @State private var authViewModel = AuthViewModel()
    
    init() {
        SupabaseManager.shared.configure(
            url: SupabaseConfig.url,
            anonKey: SupabaseConfig.anonKey
        )
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authViewModel)
        }
        .modelContainer(for: [Note.self, LocalUser.self])
    }
}
