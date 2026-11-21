import Foundation

/// Launch arguments (Debug builds only) to open the app in a given state, for screenshots and development:
/// `-demoProfile YES`, `-appTab review`, `-feedSheet filter`, `-reviewMode practice`, `-reviewSession YES`.
enum AppDebug {
    static func string(_ key: String) -> String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: key)
        #else
        return nil
        #endif
    }

    static func flag(_ key: String) -> Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }

    /// Fills a sample profile (a few lessons read, favorites, saved artworks) and skips the onboarding.
    static func prepare(_ profile: inout UserStore.Profile) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "demoProfile") else { return }
        profile.onboarded = true
        profile.firstName = "Max"
        profile.opened = ["nuit", "joconde", "perle", "vague"]
        profile.completedLessons = ["nuit", "joconde", "perle"]
        profile.favorites = ["nuit", "baiser", "vague"]
        profile.saved = ["joconde", "tournesols"]
        if UserDefaults.standard.bool(forKey: "demoEmpty") {
            profile.opened = []
            profile.completedLessons = []
            profile.favorites = []
            profile.saved = []
        }
        #endif
    }
}
