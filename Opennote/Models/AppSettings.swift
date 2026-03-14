import Foundation

/// User preferences persisted in UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var proactiveSuggestions: Bool {
        didSet { UserDefaults.standard.set(proactiveSuggestions, forKey: Keys.proactiveSuggestions) }
    }
    var suggestionFrequency: SuggestionFrequency {
        didSet { UserDefaults.standard.set(suggestionFrequency.rawValue, forKey: Keys.frequency) }
    }
    var editorFont: EditorFont {
        didSet { UserDefaults.standard.set(editorFont.rawValue, forKey: Keys.editorFont) }
    }

    enum SuggestionFrequency: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
    }

    enum EditorFont: String, CaseIterable {
        case `default` = "Default"
        case serif = "Serif"

        var description: String {
            switch self {
            case .default: return "The default all-purpose font"
            case .serif: return "Good for formal writing"
            }
        }
    }

    private enum Keys {
        static let proactiveSuggestions = "opennote.proactiveSuggestions"
        static let frequency = "opennote.suggestionFrequency"
        static let editorFont = "opennote.editorFont"
    }

    private init() {
        self.proactiveSuggestions = UserDefaults.standard.object(forKey: Keys.proactiveSuggestions) as? Bool ?? false
        let freqRaw = UserDefaults.standard.string(forKey: Keys.frequency) ?? SuggestionFrequency.moderate.rawValue
        self.suggestionFrequency = SuggestionFrequency(rawValue: freqRaw) ?? .moderate
        let fontRaw = UserDefaults.standard.string(forKey: Keys.editorFont) ?? EditorFont.default.rawValue
        self.editorFont = EditorFont(rawValue: fontRaw) ?? .default
    }
}
