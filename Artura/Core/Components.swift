import SwiftUI

// MARK: - Boutons

/// Bouton pilule avec liseré bas : il s'enfonce au toucher, avec un retour haptique.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Palette.blue
    var lip: Color = Palette.blueDark
    var foreground: Color = .white
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyStrong)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Capsule().fill(fill))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(Capsule().fill(lip).offset(y: 3))
            .animation(.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.press() }
            }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var primary: PillButtonStyle { PillButtonStyle() }
    static var secondary: PillButtonStyle {
        PillButtonStyle(fill: Palette.card, lip: Palette.lip, foreground: Palette.ink)
    }
    static var dark: PillButtonStyle {
        PillButtonStyle(fill: Palette.ink, lip: .black, foreground: .white)
    }
}

/// Style générique : légère réduction au toucher + haptique.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

struct TextLinkButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.figtree(15, .semibold))
                .foregroundStyle(Palette.blueText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Petits éléments

struct TagPill: View {
    let text: String
    var fill: Color = Palette.yellow
    var foreground: Color = Palette.ink
    var body: some View {
        Text(text)
            .font(.figtree(13, .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }
}

struct ProgressTrack: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule().fill(Palette.blue)
                    .frame(width: max(8, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
        .animation(.gentle, value: value)
    }
}

struct CheckBadge: View {
    var color: Color = Palette.blue
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
    }
}

struct StreakChip: View {
    let days: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").foregroundStyle(Palette.orange)
            Text(days <= 1 ? "\(days) jour" : "\(days) jours")
                .font(.figtree(14, .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(.white))
    }
}

// MARK: - Cartes sélectionnables

/// Ligne de réponse sélectionnable (questions de l'onboarding).
struct OptionRow: View {
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodyStrong).foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle).font(.aCaption).foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if selected {
                    CheckBadge().transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.sandLight : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
    }
}

// MARK: - Images

/// Image d'œuvre ou d'illustration, remplie et rognée, avec zoom optionnel sur un point.
struct ArtImage: View {
    let name: String
    var zoom: CGFloat = 1
    var anchor: UnitPoint = .center

    var body: some View {
        GeometryReader { geo in
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoom, anchor: anchor)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }
}

// MARK: - En-tête ciel (écrans de l'appli)

struct SkyHeader<Content: View>: View {
    var height: CGFloat = 196
    @ViewBuilder var content: () -> Content
    @State private var drift = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.sky
            Capsule().fill(Palette.skyLight).frame(width: 70, height: 26)
                .offset(x: drift ? 258 : 244, y: 52)
            Circle().fill(Palette.cloud).frame(width: 120, height: 120).offset(x: -30, y: height - 64)
            Circle().fill(Palette.cloud).frame(width: 110, height: 110).offset(x: 290, y: height - 58)
            Circle().fill(Palette.cloud).frame(width: 90, height: 90).offset(x: 350, y: height - 76)
            content()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(ArcHeaderShape())
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Apparition en cascade

struct AppearUp: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(delay * 0.5)) { shown = true }
            }
    }
}

extension View {
    /// Fait apparaître la vue par le bas, avec un délai (pour les cascades).
    func appearUp(_ delay: Double = 0) -> some View {
        modifier(AppearUp(delay: delay))
    }
}

// MARK: - Confettis

struct ConfettiView: View {
    @State private var fall = false
    private let colors: [Color] = [Palette.yellow, Palette.pink, Palette.blue, Palette.orange, Palette.green]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<36, id: \.self) { i in
                    let x = CGFloat((i * 37) % 100) / 100 * geo.size.width
                    let delay = Double((i * 13) % 10) / 20
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[i % colors.count])
                        .frame(width: 8, height: 14)
                        .rotationEffect(.degrees(fall ? Double(i * 47 % 360) : 0))
                        .position(x: x, y: fall ? geo.size.height + 40 : -40)
                        .animation(.easeIn(duration: 1.8 + Double(i % 5) * 0.2).delay(delay), value: fall)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            fall = true
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 * Double(i)) { Haptics.rigid() }
            }
        }
    }
}
