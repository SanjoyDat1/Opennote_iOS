import SwiftUI

@main
struct OpennoteApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .preferredColorScheme(.light)
        }
    }
}
