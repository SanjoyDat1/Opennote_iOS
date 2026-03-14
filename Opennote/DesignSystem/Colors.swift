import SwiftUI

extension Color {
    /// Opennote soft cream background - exact match for design system
    static let opennoteCream = Color(hex: "#FAFAF8")
    
    /// Opennote Green - primary buttons, progress indicators
    static let opennoteGreen = Color(hex: "#5E9E63")
    /// Darker green for borders (e.g. Ask Feynman bar)
    static let opennoteDarkGreen = Color(hex: "#3d6b40")
    
    /// Light green for research bar / subtle accents
    static let opennoteLightGreen = Color(hex: "#E8F5E9")
    
    /// Darker cream for paper airplane (splash) - warm tan/beige
    static let opennoteCreamDark = Color(hex: "#C9C5B8")

    // MARK: - Keyboard Accessory (match iOS system keyboard)
    /// Light gray background for keyboard accessory bar (#D1D5DB)
    static let keyboardAccessoryBackground = Color(hex: "#D1D5DB")
    /// Subtle top border separating toolbar from text area (#B0B3B8)
    static let keyboardAccessoryBorder = Color(hex: "#B0B3B8")
    /// Icon color for keyboard dismiss button (#6B7280)
    static let keyboardAccessoryIcon = Color(hex: "#6B7280")

    // MARK: - Feynman Chat Bar
    /// Placeholder text color (#9E9E9E)
    static let feynmanPlaceholder = Color(hex: "#9E9E9E")
    /// Medium gray for toolbar icons (#6B7280)
    static let feynmanToolbarIcon = Color(hex: "#6B7280")
    /// Soft shadow for floating chat bar
    static let feynmanBarShadow = Color.black.opacity(0.08)

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
