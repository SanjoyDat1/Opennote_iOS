import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var appLoadComplete = false

    var body: some View {
        Group {
            if !appViewModel.hasSeenTutorial {
                TutorialView(onComplete: {
                    appViewModel.completeTutorial()
                })
            } else if !appLoadComplete {
                AppLoadView(onComplete: {
                    appLoadComplete = true
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
        .animation(.easeInOut(duration: 0.35), value: appViewModel.hasSeenTutorial)
        .animation(.easeInOut(duration: 0.35), value: appLoadComplete)
        .animation(.easeInOut(duration: 0.35), value: appViewModel.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: appViewModel.isAuthenticated)
    }
}
