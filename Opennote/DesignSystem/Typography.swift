import SwiftUI

extension View {
    /// Major headers: "Welcome to Opennote", "Home"
    func opennoteMajorHeader() -> some View {
        font(.system(size: 32, weight: .bold, design: .serif))
    }
    
    /// Section headers: "Papers", "Journals"
    func opennoteSectionHeader() -> some View {
        font(.system(size: 17, weight: .semibold, design: .default))
    }
    
    /// Body and UI elements
    func opennoteBody() -> some View {
        font(.system(.body, design: .default))
    }
}
