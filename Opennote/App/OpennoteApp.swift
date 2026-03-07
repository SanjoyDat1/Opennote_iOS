import SwiftUI

@main
struct OpennoteApp: App {
    @State private var appViewModel = AppViewModel()
    @State private var notesStore = NotesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .environment(notesStore)
                .preferredColorScheme(.light)
        }
    }
}
