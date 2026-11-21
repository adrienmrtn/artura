import SwiftUI

/// Langue de l'habillage du cours (boutons, consignes). Le texte du cours, lui, vient de l'œuvre.
/// L'appli est en français ; l'onboarding, en anglais, affiche un extrait de cours dans sa langue.
enum LessonLanguage {
    case french
    case english

    func pick(_ french: String, _ english: String) -> String {
        self == .english ? english : french
    }

    /// Nom d'un bloc interactif (« Visite guidée », « Trouve-le »…).
    func title(of block: LessonBlock) -> String {
        guard self == .english, block.title == nil else { return block.interactiveTitle }
        switch block.type {
        case "tour": return "Guided tour"
        case "find": return "Find it"
        case "lines": return "Composition lines"
        case "palette": return "The palette"
        default: return "Free zoom"
        }
    }
}

private struct LessonLanguageKey: EnvironmentKey {
    static let defaultValue = LessonLanguage.french
}

extension EnvironmentValues {
    var lessonLanguage: LessonLanguage {
        get { self[LessonLanguageKey.self] }
        set { self[LessonLanguageKey.self] = newValue }
    }
}
