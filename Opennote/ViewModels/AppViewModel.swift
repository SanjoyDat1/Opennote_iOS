import Foundation

private enum StorageKeys {
    static let hasSeenSplash = "opennote.hasSeenSplash"
    static let hasCompletedOnboarding = "opennote.hasCompletedOnboarding"
    static let isAuthenticated = "opennote.isAuthenticated"
}

@Observable
final class AppViewModel {
    /// Auth state - nil = not logged in, non-nil = logged in
    var currentUser: OpennoteUser?

    /// Onboarding: has user completed "How did you hear about Opennote?"
    var hasCompletedOnboarding: Bool

    /// Splash: has user seen splash (or skipped)
    var hasSeenSplash: Bool

    /// Onboarding: selected referral source (for MVP)
    var referralSource: String?

    init(
        currentUser: OpennoteUser? = nil,
        hasCompletedOnboarding: Bool = false,
        hasSeenSplash: Bool = false,
        referralSource: String? = nil
    ) {
        let defaults = UserDefaults.standard
        self.hasSeenSplash = defaults.bool(forKey: StorageKeys.hasSeenSplash)
        self.hasCompletedOnboarding = defaults.bool(forKey: StorageKeys.hasCompletedOnboarding)
        self.referralSource = referralSource
        if defaults.bool(forKey: StorageKeys.isAuthenticated) {
            self.currentUser = OpennoteUser(id: "mvp-user", email: nil, name: "Sanjoy")
        } else {
            self.currentUser = currentUser
        }
    }

    var isAuthenticated: Bool { currentUser != nil }

    func skipSplash() {
        hasSeenSplash = true
        persistState()
    }

    func completeOnboarding(source: String?) {
        referralSource = source
        hasCompletedOnboarding = true
        persistState()
    }

    func signIn(user: OpennoteUser) {
        currentUser = user
        persistState()
    }

    func signOut() {
        currentUser = nil
        persistState()
    }

    private func persistState() {
        let d = UserDefaults.standard
        d.set(hasSeenSplash, forKey: StorageKeys.hasSeenSplash)
        d.set(hasCompletedOnboarding, forKey: StorageKeys.hasCompletedOnboarding)
        d.set(currentUser != nil, forKey: StorageKeys.isAuthenticated)
    }
}

struct OpennoteUser {
    let id: String
    let email: String?
    let name: String?
}
