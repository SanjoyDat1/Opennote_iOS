import SwiftUI

extension Color {
    /// Opennote soft cream background - exact match for design system
    static let opennoteCream = Color(hex: "#FAFAF8")
    
    /// Opennote Green - primary buttons, progress indicators
    static let opennoteGreen = Color(hex: "#5E9E63")
    
    /// Light green for research bar / subtle accents
    static let opennoteLightGreen = Color(hex: "#E8F5E9")
    
    /// Darker cream for paper airplane (splash) - warm tan/beige
    static let opennoteCreamDark = Color(hex: "#C9C5B8")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
