import SwiftUI

// Briques communes à tous les écrans de l'onboarding : entrées en cascade, personnage,
// bulle, texte qui s'écrit, mur de tableaux, rayons, rangées de réponse.

// MARK: - Entrée en cascade

struct EnterModifier: ViewModifier {
    let order: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(.settle.delay(0.1 + order * 0.09)) { shown = true }
            }
    }
}

extension View {
    /// Fait entrer l'élément à son tour : 0 pour le premier, 1 pour le suivant, etc.
    func enter(_ order: Double = 0) -> some View {
        modifier(EnterModifier(order: order))
    }
}

// MARK: - Chiffres mis en avant

/// Chiffres affichés dans l'onboarding.
/// À remplacer par les vrais (utilisateurs, note de la fiche App Store) avant la mise en ligne.
enum SocialProof {
    static let learners = "100 000"
    static let rating = "4,8"
}

// MARK: - Le personnage : la Joconde

/// La Joconde de l'icône, qui guide l'onboarding. Elle flotte doucement.
struct Mascot: View {
    var size: CGFloat = 132
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("joconde")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: float ? -3 : 3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
            }
            .accessibilityHidden(true)
    }
}

/// Bulle de dialogue : un rectangle arrondi avec une pointe vers le haut, au centre.
struct BubbleShape: Shape {
    var radius: CGFloat = 26
    var tail: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
        var p = Path(roundedRect: body, cornerRadius: radius, style: .continuous)
        p.move(to: CGPoint(x: rect.midX - tail * 1.1, y: body.minY + 1))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + tail * 1.1, y: body.minY + 1))
        p.closeSubpath()
        return p
    }
}

/// La Joconde au-dessus d'une bulle : ce qu'elle « dit » est le contenu.
struct MascotBubble<Content: View>: View {
    var mascotSize: CGFloat = 132
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Le bas du buste passe derrière la bulle.
        VStack(spacing: -14) {
            Mascot(size: mascotSize)
            content()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity)
                .background(
                    BubbleShape()
                        .fill(.white)
                        .shadow(color: Palette.blueDark.opacity(0.10), radius: 18, y: 8)
                )
        }
    }
}

// MARK: - Texte qui s'écrit

/// Le texte apparaît lettre par lettre. La place est réservée dès le départ : rien ne bouge autour.
struct TypewriterText: View {
    let text: String
    var font: Font = .figtree(26, .semibold)
    var charDelay: Double = 0.03
    var startDelay: Double = 0.6

    @State private var count = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let characters = Array(text)
        let shown = String(characters.prefix(count))
        let hidden = String(characters.dropFirst(count))
        return (Text(shown) + Text(hidden).foregroundColor(.clear))
            .font(font)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
            .task { await write() }
    }

    @MainActor
    private func write() async {
        let characters = Array(text)
        if reduceMotion {
            count = characters.count
            return
        }
        try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
        while count < characters.count {
            if Task.isCancelled { return }
            let character = characters[count]
            count += 1
            if count % 3 == 0 { Haptics.whisper() }
            // Une respiration après la ponctuation, comme quand on parle.
            let pause: Double
            switch character {
            case ".", ":", "!", "?": pause = charDelay * 10
            case ",": pause = charDelay * 6
            default: pause = charDelay
            }
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
        Haptics.soft()
    }
}

// MARK: - Mur de tableaux qui défilent

/// Des rangées de petits tableaux carrés qui glissent en sens opposés, en ondulant légèrement.
struct FloatingWall: View {
    var tile: CGFloat = 80
    var spacing: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Trois rangées, sans jamais répéter une œuvre d'une rangée à l'autre.
    private static let rows: [[String]] = [
        ["art_nuit", "wall_venus", "art_perle", "wall_cri", "wall_amandier", "art_baiser", "wall_menines", "wall_fuji", "art_raboteurs"],
        ["wall_laitiere", "art_vague", "wall_cafe", "art_joconde", "wall_grandejatte", "wall_hermine", "art_tournesols", "wall_babel", "wall_danse"],
        ["art_impression", "wall_galette", "wall_voyageur", "art_nympheas", "wall_adele", "wall_chambre", "wall_glaneuses", "art_moine", "wall_fifre", "wall_ronde"]
    ]
    /// Vitesse de chaque rangée, en points par seconde (négatif : vers la droite).
    private static let speeds: [Double] = [16, -20, 13]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: spacing) {
                ForEach(0..<Self.rows.count, id: \.self) { row in
                    rowView(Self.rows[row], row: row, time: time)
                }
            }
        }
        // Les bords s'estompent : les tableaux entrent et sortent en douceur.
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        )
        .accessibilityHidden(true)
    }

    private func rowView(_ images: [String], row: Int, time: Double) -> some View {
        let step = Double(tile + spacing)
        let period = step * Double(images.count)
        var shift = (time * Self.speeds[row % Self.speeds.count]).truncatingRemainder(dividingBy: period)
        if shift < 0 { shift += period }
        // La rangée est posée deux fois bout à bout : la boucle ne se voit pas.
        return Color.clear
            .frame(height: tile + 14)
            .overlay(alignment: .leading) {
                HStack(spacing: spacing) {
                    ForEach(0..<(images.count * 2), id: \.self) { i in
                        let wave = Double(i % images.count) * 0.9 + Double(row) * 1.7
                        Image(images[i % images.count])
                            .resizable()
                            .scaledToFill()
                            .frame(width: tile, height: tile)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white, lineWidth: 3)
                            )
                            .rotationEffect(.degrees(sin(time * 0.55 + wave) * 2.4))
                            .offset(y: CGFloat(sin(time * 0.8 + wave) * 5))
                    }
                }
                .fixedSize()
                .offset(x: CGFloat(-shift))
            }
    }
}

// MARK: - Rayons et étincelles (écrans de cadeau)

/// Rayons qui partent du centre, comme un soleil.
struct Sunburst: Shape {
    var rays: Int = 14

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height)
        let step = 2 * CGFloat.pi / CGFloat(rays)
        for i in 0..<rays {
            let from = CGFloat(i) * step
            let to = from + step * 0.42
            p.move(to: center)
            p.addLine(to: CGPoint(x: center.x + cos(from) * radius, y: center.y + sin(from) * radius))
            p.addLine(to: CGPoint(x: center.x + cos(to) * radius, y: center.y + sin(to) * radius))
            p.closeSubpath()
        }
        return p
    }
}

/// Fond de rayons dorés qui tournent très lentement.
struct RaysBackground: View {
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Sunburst()
            .fill(Palette.yellow.opacity(0.17))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .mask(
                RadialGradient(colors: [.black, .black.opacity(0.85), .clear],
                               center: .center, startRadius: 40, endRadius: 520)
            )
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 70).repeatForever(autoreverses: false)) { spin = true }
            }
            .accessibilityHidden(true)
    }
}

/// Étincelle à quatre branches.
struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

// MARK: - Rangée de réponse

/// Réponse sélectionnable des questions de l'onboarding (choix unique ou multiple).
struct ChoiceRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    let selected: Bool
    var multiple: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? .white : Palette.blue)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(selected ? Palette.blue : Palette.sand))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodyStrong).foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle).font(.aCaption).foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                // Rond pour un choix unique, carré arrondi pour un choix multiple.
                ZStack {
                    RoundedRectangle(cornerRadius: multiple ? 8 : 13)
                        .fill(selected ? Palette.blue : Color.clear)
                    RoundedRectangle(cornerRadius: multiple ? 8 : 13)
                        .stroke(selected ? Palette.blue : Palette.lip, lineWidth: 2)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(selected ? 1 : 0.4)
                        .opacity(selected ? 1 : 0)
                }
                .frame(width: 26, height: 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Palette.sandLight : Palette.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? Palette.blue : Palette.line, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
