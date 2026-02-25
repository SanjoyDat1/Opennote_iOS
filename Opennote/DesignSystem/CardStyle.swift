import SwiftUI

/// Opennote card/surface styling - pure white with subtle shadow and rounded corners
struct OpennoteCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func opennoteCard() -> some View {
        modifier(OpennoteCardModifier())
    }
}
