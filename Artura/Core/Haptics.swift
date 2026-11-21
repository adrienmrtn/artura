import UIKit

/// Haptic feedback used throughout the app.
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

    /// Barely perceptible vibration (a word appearing, an ignored tap).
    static func whisper() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
    }

    /// Variable-intensity vibration (0 to 1), for gradual build-ups.
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
