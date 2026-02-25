import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        Group {
            if !appViewModel.hasSeenSplash {
                SplashView(onSkip: {
                    appViewModel.skipSplash()
                })
            } else if !appViewModel.isAuthenticated {
                if !appViewModel.hasCompletedOnboarding {
                    OnboardingView(onComplete: { source in
                        appViewModel.completeOnboarding(source: source)
                    })
                } else {
                    LoginView()
                }
            } else {
                MainContainerView()
            }
        }
    }
}
