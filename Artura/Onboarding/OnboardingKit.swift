import SwiftUI

// Building blocks shared by all onboarding screens: staggered entrances, character,
// speech bubble, typed text, wall of paintings, rays, answer rows.

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
    /// Brings the element in when its turn comes: 0 for the first, 1 for the next, and so on.
    func enter(_ order: Double = 0) -> some View {
        modifier(EnterModifier(order: order))
    }
}

// MARK: - Featured numbers

/// Numbers shown in the onboarding.
/// To be replaced with the real ones (users, App Store rating) before release.
enum SocialProof {
    static let learners = "100,000"
    static let rating = "4.8"
    /// Sample reviews: to be replaced with real App Store reviews.
    static let reviews = [
        "Five minutes in the morning, and I finally see paintings differently.",
        "The mini-games really help me remember names and dates.",
        "I knew nothing about art. Now I look forward to the notification."
    ]
}

// MARK: - The character: the Mona Lisa

/// The Mona Lisa from the app icon, who guides the onboarding. She floats gently.
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

/// Speech bubble: a rounded rectangle with a tail pointing up, in the center.
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

// MARK: - The Mona Lisa speaks: typed text, one line after another

/// Dialogue screen: the Mona Lisa says one or more lines, typed letter by letter at a steady pace.
/// A tap while typing shows the whole line; the next tap moves on.
struct MascotTalkScreen<Extra: View>: View {
    let lines: [String]
    /// Button label on the last line.
    var cta: String = "Continue"
    var mascotSize: CGFloat = 156
    let onNext: () -> Void
    /// Content shown under the bubble, on the last line.
    @ViewBuilder var extra: () -> Extra

    @State private var index = min(max(0, OnboardingDebug.int("onbLine")), 9)
    /// Seconds since the current line started to appear.
    @State private var elapsed: Double = 0
    @State private var typing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Each letter lands crisply, as if typed; this very short fade only removes the flicker between frames.
    private let fade = 0.05

    private var line: String { lines[min(index, lines.count - 1)] }
    private var isLast: Bool { index >= lines.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            MascotBubble(mascotSize: mascotSize) {
                typedText
                    .id(index)
                    .transition(.opacity)
            }
            .enter()

            if lines.count > 1 {
                // Where we are in the conversation
                HStack(spacing: 6) {
                    ForEach(0..<lines.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? Palette.blue : Palette.lip)
                            .frame(width: i == index ? 18 : 6, height: 6)
                    }
                }
                .padding(.top, 18)
                .animation(.gentle, value: index)
                .accessibilityHidden(true)
            }

            if isLast {
                extra()
                    .padding(.top, 18)
                    .transition(.opacity.combined(with: .offset(y: 10)))
            }

            Spacer(minLength: 16)
            Spacer(minLength: 0)

            Button(isLast ? cta : "Continue") { advance() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .task(id: index) { await write() }
    }

    /// When each letter starts to appear, with a breath after punctuation, as when speaking.
    private func schedule(_ characters: [Character]) -> [Double] {
        var times: [Double] = []
        var t = 0.0
        for character in characters {
            times.append(t)
            switch character {
            case ".", ":", "!", "?": t += 0.20
            case ",": t += 0.10
            default: t += 0.03
            }
        }
        return times
    }

    /// Room for the whole line is reserved from the start: the bubble doesn't move while the text appears.
    /// The pace follows the clock, not a timer per letter, so the typing never stutters.
    private var typedText: some View {
        let characters = Array(line)
        let times = schedule(characters)
        var shown = 0
        while shown < characters.count, elapsed >= times[shown] + fade { shown += 1 }
        var text = Text(String(characters.prefix(shown)))
        var i = shown
        while i < characters.count, elapsed > times[i] {
            let opacity = min(1, (elapsed - times[i]) / fade)
            text = text + Text(String(characters[i])).foregroundColor(Palette.ink.opacity(opacity))
            i += 1
        }
        text = text + Text(String(characters.dropFirst(i))).foregroundColor(.clear)
        return text
            .font(.figtree(24, .semibold))
            .foregroundStyle(Palette.ink)
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(line)
    }

    private func advance() {
        if typing {
            // First tap: show the whole line.
            typing = false
            elapsed = .greatestFiniteMagnitude
            Haptics.tap()
        } else if !isLast {
            elapsed = 0
            typing = true
            withAnimation(.settle) { index += 1 }
        } else {
            onNext()
        }
    }

    @MainActor
    private func write() async {
        let characters = Array(line)
        if reduceMotion {
            elapsed = .greatestFiniteMagnitude
            typing = false
            return
        }
        let times = schedule(characters)
        let total = (times.last ?? 0) + fade
        typing = true
        elapsed = 0
        try? await Task.sleep(nanoseconds: 450_000_000)
        let start = Date()
        var ticks = 0
        while typing {
            if Task.isCancelled { return }
            let now = Date().timeIntervalSince(start)
            if now >= total { break }
            elapsed = now
            // A light tick every few letters.
            let reached = times.prefix { $0 <= now }.count
            if reached / 4 > ticks { ticks = reached / 4; Haptics.whisper() }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        if Task.isCancelled { return }
        if typing { Haptics.soft() }
        elapsed = .greatestFiniteMagnitude
        typing = false
    }
}

extension MascotTalkScreen where Extra == EmptyView {
    init(lines: [String], cta: String = "Continue", mascotSize: CGFloat = 156, onNext: @escaping () -> Void) {
        self.init(lines: lines, cta: cta, mascotSize: mascotSize, onNext: onNext) { EmptyView() }
    }
}

// MARK: - Counting number

/// Whole number that counts up or down smoothly when its value is animated.
struct CountingText: View, Animatable {
    var value: Double
    var suffix: String = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))\(suffix)")
    }
}

// MARK: - Paintings floating in space

/// Scattered paintings drifting slowly, as if weightless. Used as a backdrop behind content.
struct FloatingSpace: View {
    /// Number of paintings already shown (they come in one by one).
    var shown: Int = FloatingSpace.count
    /// If true, a sculpture slips in among the paintings.
    var withSculpture: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item {
        let image: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let depth: Double
    }

    // Placed around the edges: the center stays free for the text.
    private static let items: [Item] = [
        Item(image: "wall_venus", x: 0.12, y: 0.07, size: 66, depth: 1.0),
        Item(image: "art_nuit", x: 0.84, y: 0.06, size: 72, depth: 1.0),
        Item(image: "wall_cri", x: 0.48, y: 0.03, size: 50, depth: 0.6),
        Item(image: "art_perle", x: 0.94, y: 0.27, size: 56, depth: 0.75),
        Item(image: "wall_laitiere", x: 0.05, y: 0.29, size: 58, depth: 0.8),
        Item(image: "wall_menines", x: 0.90, y: 0.50, size: 60, depth: 0.9),
        Item(image: "art_vague", x: 0.08, y: 0.53, size: 52, depth: 0.65),
        Item(image: "wall_cafe", x: 0.16, y: 0.77, size: 68, depth: 1.0),
        Item(image: "art_baiser", x: 0.84, y: 0.74, size: 66, depth: 0.95),
        Item(image: "wall_amandier", x: 0.50, y: 0.86, size: 54, depth: 0.7),
        Item(image: "wall_grandejatte", x: 0.30, y: 0.95, size: 56, depth: 0.8),
        Item(image: "art_tournesols", x: 0.70, y: 0.96, size: 50, depth: 0.6),
        Item(image: "wall_fuji", x: 0.95, y: 0.92, size: 52, depth: 0.7),
        Item(image: "wall_hermine", x: 0.03, y: 0.93, size: 50, depth: 0.6)
    ]

    static var count: Int { items.count }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<Self.items.count, id: \.self) { i in
                        let item = Self.items[i]
                        let phase = Double(i) * 1.37
                        let visible = i < shown
                        Image(withSculpture && i == 5 ? "ill_sculpture" : item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: item.size, height: item.size)
                            .clipShape(RoundedRectangle(cornerRadius: item.size * 0.22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: item.size * 0.22, style: .continuous)
                                    .stroke(.white, lineWidth: 3)
                            )
                            .opacity(visible ? 0.35 + 0.65 * item.depth : 0)
                            .scaleEffect(visible ? 1 : 0.5)
                            .rotationEffect(.degrees(sin(time * 0.35 + phase) * 6))
                            .position(
                                x: geo.size.width * item.x + CGFloat(sin(time * 0.27 + phase) * 9 * item.depth),
                                y: geo.size.height * item.y + CGFloat(cos(time * 0.22 + phase * 1.3) * 12 * item.depth)
                            )
                            .animation(.settle, value: visible)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Scrolling wall of paintings

/// Rows of small square paintings gliding in opposite directions, swaying slightly.
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
        // The edges fade out: the paintings come and go smoothly.
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

/// Rays spreading from the center, like a sun.
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

/// Background of golden rays turning very slowly.
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
/// A plain light card; once chosen, a pale blue card with a blue outline and a check.
struct ChoiceRow: View {
    let title: String
    var subtitle: String? = nil
    /// Name of a small grainy illustration shown at the start of the row.
    var image: String? = nil
    let selected: Bool
    var multiple: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let image {
                    Image(image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodyStrong)
                        .foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.aCaption)
                            .foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                // Circle for a single choice, rounded square for a multiple choice.
                ZStack {
                    RoundedRectangle(cornerRadius: multiple ? 8 : 13)
                        .fill(selected ? Palette.blue : Color.white)
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
            .padding(.leading, image == nil ? 18 : 10)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: image == nil ? 64 : 66, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.mistLight : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
