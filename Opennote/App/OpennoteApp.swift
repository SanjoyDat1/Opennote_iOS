import SwiftUI
import UIKit

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
                .onAppear {
                    #if targetEnvironment(simulator)
                    // Force software keyboard to show in simulator (else Cmd+K to toggle)
                    let setHardwareLayout = NSSelectorFromString("setHardwareLayout:")
                    for mode in UITextInputMode.activeInputModes {
                        if mode.responds(to: setHardwareLayout) {
                            mode.perform(setHardwareLayout, with: nil)
                            break
                        }
                    }
                    #endif
                }
        }
    }
}
