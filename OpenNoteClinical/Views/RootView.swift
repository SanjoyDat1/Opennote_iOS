import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }
}
