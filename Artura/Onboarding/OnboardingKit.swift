import SwiftUI

// Building blocks shared by all onboarding screens: staggered entrances, character,
// bubble, typewriter text, wall of paintings, rays, answer rows.

// MARK: - Staggered entrance

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
    /// Brings the element in at its turn: 0 for the first, 1 for the next, etc.
    func enter(_ order: Double = 0) -> some View {
        modifier(EnterModifier(order: order))
    }
}

// MARK: - Featured numbers

/// Numbers shown in the onboarding.
/// Replace with the real ones (users, App Store rating) before release.
enum SocialProof {
    static let learners = "100,000"
    static let rating = "4.8"
}

// MARK: - The character: the Mona Lisa

/// The Mona Lisa from the icon, who guides the onboarding. She floats gently.
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

/// Speech bubble: a rounded rectangle with a tail pointing up, centered.
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

/// The Mona Lisa above a bubble: what she "says" is the content.
struct MascotBubble<Content: View>: View {
    var mascotSize: CGFloat = 132
    @ViewBuilder var content: () -> Content

    var body: some View {
        // The bottom of the bust goes behind the bubble.
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

// MARK: - Typewriter text

/// The text appears letter by letter. The space is reserved from the start: nothing moves around it.
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
            // A breath after punctuation, like when speaking.
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

// MARK: - Scrolling wall of paintings

/// Rows of small square paintings sliding in opposite directions, swaying slightly.
struct FloatingWall: View {
    var tile: CGFloat = 80
    var spacing: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Three rows, never repeating an artwork from one row to another.
    private static let rows: [[String]] = [
        ["art_nuit", "wall_venus", "art_perle", "wall_cri", "wall_amandier", "art_baiser", "wall_menines", "wall_fuji", "art_raboteurs"],
        ["wall_laitiere", "art_vague", "wall_cafe", "art_joconde", "wall_grandejatte", "wall_hermine", "art_tournesols", "wall_babel", "wall_danse"],
        ["art_impression", "wall_galette", "wall_voyageur", "art_nympheas", "wall_adele", "wall_chambre", "wall_glaneuses", "art_moine", "wall_fifre", "wall_ronde"]
    ]
    /// Speed of each row, in points per second (negative: to the right).
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
        // The edges fade out: paintings come in and out gently.
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
        // The row is laid out twice end to end: the loop is invisible.
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

// MARK: - Rays and sparkles (gift screens)

/// Rays radiating from the center, like a sun.
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

/// Background of golden rays that rotate very slowly.
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

/// Four-pointed sparkle.
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

// MARK: - Answer row

/// Selectable answer for onboarding questions (single or multiple choice).
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
                // Circle for single choice, rounded square for multiple choice.
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
