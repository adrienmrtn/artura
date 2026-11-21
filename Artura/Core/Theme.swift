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

/// Palette inspirée de l'icône : bleu nuit, crème, ocre et terre cuite.
enum Palette {
    /// Fond des écrans : un beige chaud, comme un papier à dessin.
    static let bg = Color(hex: 0xFAF3E7)
    static let ink = Color(hex: 0x18233A)
    static let muted = Color(hex: 0x5B6272)
    /// Cartes et rangées posées sur le fond.
    static let card = Color(hex: 0xFFFDFA)
    static let line = Color(hex: 0xEDE3D3)
    static let lip = Color(hex: 0xDCCFBA)
    /// Couleur principale : boutons, sélection, liens.
    static let navy = Color(hex: 0x1C365A)
    static let navyDark = Color(hex: 0x0D1D36)
    /// Teintes chaudes pour les fonds d'encart et les éléments sélectionnés.
    static let sand = Color(hex: 0xF3E3C3)
    static let sandLight = Color(hex: 0xFBEED3)
    static let sky = Color(hex: 0x1C365A)
    static let skyLight = Color(hex: 0x2C4A77)
    static let cloud = Color(hex: 0xF3D9A4)
    static let yellow = Color(hex: 0xEFAE3C)
    static let orange = Color(hex: 0xD9572B)
    static let pink = Color(hex: 0xF3B9A3)
    static let green = Color(hex: 0x2E7D58)
    static let greenSoft = Color(hex: 0xE1F0E4)
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

    /// Police à empattements du système (New York), pour les titres.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let aTitle = Font.serif(30)
    static let aTitleSmall = Font.serif(26)
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
    // Courbes simples, sans ressort : aucun rebond.
    static let snappy = Animation.easeOut(duration: 0.16)
    static let gentle = Animation.easeInOut(duration: 0.24)
    static let bouncy = Animation.easeOut(duration: 0.2)
    /// Glissement entre deux écrans : départ vif, arrivée très douce.
    static let glide = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.55)
    /// Entrée d'un élément dans l'écran.
    static let settle = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)
}
