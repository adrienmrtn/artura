import SwiftUI
import UIKit

/// Appearance chosen in the profile: light (the default), dark, or the phone's setting.
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system

    /// UserDefaults key (also settable with the launch argument `-appearance dark` in Debug captures).
    static let key = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return L("Light")
        case .dark: return L("Dark")
        case .system: return L("Same as phone")
        }
    }

    /// For `.preferredColorScheme`: nil follows the phone.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return .unspecified
        }
    }

    /// Sets the appearance on every window of the app (sheets and covers included).
    /// `.preferredColorScheme(nil)` alone does not always go back to the phone's setting.
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}
