import Foundation

/// App Store rating prompt during the first lesson opened in the app, at the 5th tap on "Continue".
/// Asked once ever. The onboarding's guided tour is not concerned (it asks on its own screen).
enum RatingPrompt {
    /// Number of "Continue" taps after which the prompt is asked.
    static let lessonTap = 5
    private static let firstKey = "ratingFirstLesson"
    private static let askedKey = "ratingLessonAsked"

    /// Remembers the first artwork whose lesson is opened in the app.
    static func noteOpened(_ id: String) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: firstKey) == nil { defaults.set(id, forKey: firstKey) }
    }

    /// True once: at the 5th "Continue" of the first lesson opened. Marks the prompt as asked.
    static func shouldAsk(artwork id: String, taps: Int) -> Bool {
        let defaults = UserDefaults.standard
        guard taps == lessonTap, !defaults.bool(forKey: askedKey),
              defaults.string(forKey: firstKey) == id else { return false }
        defaults.set(true, forKey: askedKey)
        return true
    }
}
