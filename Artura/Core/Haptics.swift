import UIKit

/// Retours haptiques utilisés partout dans l'appli.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func press() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    /// Vibration à peine perceptible (mot qui apparaît, appui ignoré).
    static func whisper() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
    }

    /// Vibration d'intensité variable (0 à 1), pour les montées progressives.
    static func rise(_ intensity: Double) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(intensity))
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
