import SwiftUI
import CoreText

// MARK: - Couleurs

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

    /// "#RRGGBB" → Color. Retourne du gris si la chaîne est invalide.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(cleaned, radix: 16) ?? 0x888888
        self.init(hex: value)
    }
}

enum Palette {
    static let ink = Color(hex: 0x2D2C2B)
    static let muted = Color(hex: 0x5C5753)
    static let card = Color(hex: 0xF9F4F2)
    static let line = Color(hex: 0xF1EAE6)
    static let lip = Color(hex: 0xE4DAD4)
    static let blue = Color(hex: 0x0061EF)
    static let blueDark = Color(hex: 0x0045B5)
    static let blueText = Color(hex: 0x0050C8)
    static let blueSoft = Color(hex: 0xDCEBFF)
    static let blueSelected = Color(hex: 0xEAF2FF)
    static let sky = Color(hex: 0x0B74E5)
    static let skyLight = Color(hex: 0x4D9DF2)
    static let cloud = Color(hex: 0xFFD3E4)
    static let yellow = Color(hex: 0xFFB000)
    static let orange = Color(hex: 0xFF6800)
    static let pink = Color(hex: 0xFF8FBC)
    static let green = Color(hex: 0x00804A)
    static let greenSoft = Color(hex: 0xE3F6EA)
    static let red = Color(hex: 0xB3261E)
    static let redSoft = Color(hex: 0xFCE8E6)
}

// MARK: - Typographie (Figtree, embarquée dans le bundle)

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

    static let aTitle = Font.figtree(30, .semibold)
    static let aTitleSmall = Font.figtree(26, .semibold)
    static let aHeading = Font.figtree(20, .semibold)
    static let aCardTitle = Font.figtree(18, .semibold)
    static let aBody = Font.figtree(16)
    static let bodyStrong = Font.figtree(16, .semibold)
    static let aSmall = Font.figtree(14)
    static let aCaption = Font.figtree(13)
}

// MARK: - Formes

/// Zone d'en-tête dont le bord bas est un arc légèrement incliné.
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

/// Panneau de bas d'écran dont le bord haut est un arc incliné.
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
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.88)
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.62)
}
