import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel

    /// Controls whether the splash screen is visible.
    /// Starts true; set to false after the user swipes up to enter.
    @State private var showLoadScreen = true

    /// Scale/corner of the destination view while the splash sits on top.
    /// Mirrors the iOS "card stack" depth effect used for sheets and Spotlight.
    @State private var behindScale: CGFloat = 0.93
    @State private var behindCorner: CGFloat = 16

    var body: some View {
        ZStack {
            if !appViewModel.hasSeenTutorial {
                // ── Tutorial: no splash, just direct transition ───────────
                TutorialView(onComplete: {
                    appViewModel.completeTutorial()
                })
                .transition(.opacity)

            } else {
                // ── Post-tutorial: splash overlaid on real content ────────

                // Dark stage background — visible in the gap around the scaled card
                Color.black.ignoresSafeArea()

                // Real destination content — rendered and loaded behind the splash.
                // Slightly scaled & rounded to create the native "card behind sheet" look.
                destinationView
                    .scaleEffect(behindScale)
                    .clipShape(RoundedRectangle(cornerRadius: behindCorner, style: .continuous))
                    .allowsHitTesting(!showLoadScreen)  // non-interactive while splash is up
                    .animation(.spring(response: 0.52, dampingFraction: 0.84), value: behindScale)
                    .animation(.spring(response: 0.52, dampingFraction: 0.84), value: behindCorner)

                // Splash screen overlay — slides up and peels away on swipe
                if showLoadScreen {
                    AppLoadView {
                        // Called when the swipe-up gesture commits.
                        // Spring the underlying content to full size, then remove the overlay.
                        behindScale = 1.0
                        behindCorner = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showLoadScreen = false
                        }
                    }
                    .transition(.identity)  // AppLoadView drives its own exit animation
                    .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.30), value: appViewModel.hasSeenTutorial)
        .animation(.easeInOut(duration: 0.30), value: appViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.30), value: appViewModel.hasCompletedOnboarding)
    }

    // MARK: - Destination (what lives behind the splash)

    @ViewBuilder
    private var destinationView: some View {
        if !appViewModel.isAuthenticated {
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
