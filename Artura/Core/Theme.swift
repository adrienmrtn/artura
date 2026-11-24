import SwiftUI
import CoreText

// MARK: - Colors

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color with a light and a dark value, following the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// "#RRGGBB" → Color. Returns gray if the string is invalid.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(cleaned, radix: 16) ?? 0x888888
        self.init(hex: value)
    }
}

/// Colors of the app. Each one has a light and a dark value and follows the system appearance.
enum Palette {
    /// Screen background: plain white (warm near-black in dark mode).
    static let bg = Color(light: 0xFFFFFF, dark: 0x141312)
    static let ink = Color(light: 0x2D2C2B, dark: 0xF3EFEC)
    static let muted = Color(light: 0x5C5753, dark: 0xACA59F)
    /// Cards and rows laid on the background: very light warm greys.
    static let card = Color(light: 0xF9F4F2, dark: 0x201E1C)
    static let line = Color(light: 0xEFE8E3, dark: 0x2E2B29)
    static let lip = Color(light: 0xE4DAD4, dark: 0x3B3734)
    /// Bright blue: buttons, selection, links.
    static let blue = Color(light: 0x0061EF, dark: 0x2B78FF)
    static let blueDark = Color(light: 0x0045B5, dark: 0x1A52BE)
    static let blueText = Color(light: 0x0050C8, dark: 0x75AEFF)
    /// Pale tints of the blue, for insets and selected answers.
    static let mist = Color(light: 0xDCEBFF, dark: 0x182A4D)
    static let mistLight = Color(light: 0xEAF2FF, dark: 0x121E36)
    static let sky = Color(light: 0x0B74E5, dark: 0x0B74E5)
    static let skyLight = Color(light: 0x4D9DF2, dark: 0x4D9DF2)
    static let cloud = Color(light: 0xFFD3E4, dark: 0x4C2536)
    static let yellow = Color(light: 0xFFB000, dark: 0xFFB000)
    static let orange = Color(light: 0xFF6800, dark: 0xFF7A1F)
    static let pink = Color(light: 0xFF8FBC, dark: 0xFF8FBC)
    static let green = Color(light: 0x00804A, dark: 0x3CC98A)
    static let greenSoft = Color(light: 0xE3F6EA, dark: 0x12301F)
    static let red = Color(light: 0xB3261E, dark: 0xFF6B61)
    static let redSoft = Color(light: 0xFCE8E6, dark: 0x3B1816)
}

// MARK: - Typography (Figtree, embedded in the bundle)

enum FontRegistrar {
    static func registerAll() {
        for name in ["Figtree_400Regular", "Figtree_500Medium", "Figtree_600SemiBold", "Figtree_700Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static func figtree(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Figtree-Bold"
        case .semibold: name = "Figtree-SemiBold"
        case .medium: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }

    /// Police à empattements du système, réservée aux citations.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let aTitle = Font.figtree(30, .semibold)
    static let aTitleSmall = Font.figtree(26, .semibold)
    static let aHeading = Font.figtree(20, .semibold)
    static let aCardTitle = Font.figtree(18, .semibold)
    static let aBody = Font.figtree(16)
    static let bodyStrong = Font.figtree(16, .semibold)
    static let aSmall = Font.figtree(14)
    static let aCaption = Font.figtree(13)
}

// MARK: - Shapes

/// Header area whose bottom edge is a slightly tilted arc.
struct ArcHeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 26))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - 16),
            control: CGPoint(x: rect.minX + rect.width * 0.487, y: rect.maxY - 74)
        )
        p.closeSubpath()
        return p
    }
}

/// Bottom-of-screen panel whose top edge is a tilted arc.
struct ArcTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 8),
            control: CGPoint(x: rect.minX + rect.width * 0.51, y: rect.minY + 34)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Animations

extension Animation {
    // Simple curves, no spring: no bounce.
    static let snappy = Animation.easeOut(duration: 0.16)
    static let gentle = Animation.easeInOut(duration: 0.24)
    static let bouncy = Animation.easeOut(duration: 0.2)
    /// Glissement entre deux écrans : départ vif, arrivée très douce.
    static let glide = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.55)
    /// Entrée d'un élément dans l'écran.
    static let settle = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)
}
