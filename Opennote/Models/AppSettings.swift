import Foundation

/// User preferences for AI suggestions, frequency, etc. Persisted in UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var proactiveSuggestions: Bool {
        didSet { UserDefaults.standard.set(proactiveSuggestions, forKey: Keys.proactiveSuggestions) }
    }
    var suggestionFrequency: SuggestionFrequency {
        didSet { UserDefaults.standard.set(suggestionFrequency.rawValue, forKey: Keys.frequency) }
    }

    enum SuggestionFrequency: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
    }

    private enum Keys {
        static let proactiveSuggestions = "opennote.proactiveSuggestions"
        static let frequency = "opennote.suggestionFrequency"
    }

    private init() {
        self.proactiveSuggestions = UserDefaults.standard.object(forKey: Keys.proactiveSuggestions) as? Bool ?? false
        let freqRaw = UserDefaults.standard.string(forKey: Keys.frequency) ?? SuggestionFrequency.moderate.rawValue
        self.suggestionFrequency = SuggestionFrequency(rawValue: freqRaw) ?? .moderate
    }
}
