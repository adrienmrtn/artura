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

    /// "#RRGGBB" → Color. Returns gray if the string is invalid.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(cleaned, radix: 16) ?? 0x888888
        self.init(hex: value)
    }
}

enum Palette {
    /// Screen background: plain white.
    static let bg = Color.white
    static let ink = Color(hex: 0x2D2C2B)
    static let muted = Color(hex: 0x5C5753)
    /// Cards and rows laid on the background: very light warm greys.
    static let card = Color(hex: 0xF9F4F2)
    static let line = Color(hex: 0xEFE8E3)
    static let lip = Color(hex: 0xE4DAD4)
    /// Bright blue: buttons, selection, links.
    static let blue = Color(hex: 0x0061EF)
    static let blueDark = Color(hex: 0x0045B5)
    static let blueText = Color(hex: 0x0050C8)
    /// Pale tints of the blue, for insets and selected answers.
    static let mist = Color(hex: 0xDCEBFF)
    static let mistLight = Color(hex: 0xEAF2FF)
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
