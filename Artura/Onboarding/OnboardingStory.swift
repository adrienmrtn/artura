import SwiftUI

// MARK: - Test: how many of these paintings can you name?

/// Entry test card: two paintings everyone knows, then five much harder ones.
struct FlashCard: Identifiable {
    let id: String
    let title: String
    let artist: String
    var hard = false
    var image: String { "art_\(id)" }

    static let all: [FlashCard] = [
        FlashCard(id: "joconde", title: "Mona Lisa", artist: "Leonardo da Vinci"),
        FlashCard(id: "nuit", title: "The Starry Night", artist: "Vincent van Gogh"),
        FlashCard(id: "glaneuses", title: "The Gleaners", artist: "Jean-François Millet"),
        FlashCard(id: "menines", title: "Las Meninas", artist: "Diego Velázquez"),
        FlashCard(id: "grandejatte", title: "A Sunday Afternoon on the Island of La Grande Jatte", artist: "Georges Seurat"),
        FlashCard(id: "raboteurs", title: "The Floor Scrapers", artist: "Gustave Caillebotte", hard: true),
        FlashCard(id: "moine", title: "The Monk by the Sea", artist: "Caspar David Friedrich", hard: true)
    ]
}

struct FlashTestScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var armed = false
    @State private var known: [String] = []
    /// Cards already answered and the side they left from.
    @State private var gone: [String: CGFloat] = [:]

    private let cards = FlashCard.all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TagPill(text: L("Painting %@ of %@", "\(min(index + 1, cards.count))", "\(cards.count)"))
                Text(L("How many of these paintings can you name?"))
                    .font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("Be honest. Swipe the card, or use the buttons."))
                    .font(.aBody).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enter()

            // Stack of cards: the next one peeks out behind the top one.
            ZStack {
                ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { i, item in
                    if i <= index + 2 {
                        // An answered card keeps its off-screen place: it never comes back to the center.
                        let depth = max(0, i - index)
                        let exit = gone[item.id]
                        let x = exit ?? (i == index ? drag.width : 0)
                        card(item, top: i == index)
                            .scaleEffect(1 - CGFloat(depth) * 0.05)
                            .offset(y: CGFloat(depth) * 16)
                            .rotationEffect(.degrees(depth == 0 ? Double(x) / 22 : (depth == 1 ? 2.5 : -2.5)))
                            .offset(x: x, y: i == index ? drag.height * 0.15 : 0)
                            .opacity(exit == nil ? 1 : 0)
                            .zIndex(Double(cards.count - i))
                            .allowsHitTesting(i == index)
                    }
                }
            }
            .padding(.bottom, 34)
            .frame(maxHeight: .infinity)
            .enter(2)

            HStack(spacing: 12) {
                Button(L("I don't know")) { answer(false) }.buttonStyle(.secondary)
                Button(L("I know it")) { answer(true) }.buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Palette.bg)
    }

    private func card(_ item: FlashCard, top: Bool) -> some View {
        ArtImage(name: item.image)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.bg, lineWidth: 5))
            .shadow(color: Palette.blueDark.opacity(0.16), radius: 12, y: 6)
            .overlay(alignment: .bottomLeading) {
                if item.hard { TagPill(text: L("Expert level")).padding(16) }
            }
            .overlay(alignment: .topLeading) {
                if top { stamp(L("I know it"), Palette.green).opacity(stampOpacity(true)).padding(16) }
            }
            .overlay(alignment: .topTrailing) {
                // Dark stamp over the artwork in both appearances (ink turns light in dark mode).
                if top { stamp(L("I don't know"), Color(hex: 0x2D2C2B)).opacity(stampOpacity(false)).padding(16) }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard top else { return }
                        drag = value.translation
                        let nowArmed = abs(value.translation.width) > 90
                        if nowArmed != armed {
                            armed = nowArmed
                            Haptics.selection()
                        }
                    }
                    .onEnded { value in
                        guard top else { return }
                        if value.translation.width > 90 {
                            answer(true)
                        } else if value.translation.width < -90 {
                            answer(false)
                        } else {
                            withAnimation(.snappy) { drag = .zero }
                        }
                    }
            )
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.figtree(18, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(color))
    }

    private func stampOpacity(_ forKnown: Bool) -> Double {
        let amount = Double(drag.width) / 90
        return min(1, max(0, forKnown ? amount : -amount))
    }

    private func answer(_ knows: Bool) {
        guard cards.indices.contains(index) else { return }
        let current = cards[index]
        armed = false
        if knows {
            known.append(current.id)
            Haptics.success()
        } else {
            Haptics.rigid()
        }
        // The card leaves on the answer's side while the next one rises, in the same animation.
        let last = index >= cards.count - 1
        withAnimation(.easeOut(duration: 0.28)) {
            gone[current.id] = knows ? 520 : -520
            drag = .zero
            index += 1
        }
        if last {
            user.profile.flashKnown = known
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onNext() }
        }
    }
}

// MARK: - Test result: "Well done, Max!"

struct FlashResultScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var count = 0
    @State private var fanned = false
    @State private var verdictShown = false

    private let cards = FlashCard.all
    private var total: Int { cards.count }
    private var score: Int { cards.filter { user.profile.flashKnown.contains($0.id) }.count }

    private var firstName: String? {
        guard let name = user.profile.firstName, !name.isEmpty else { return nil }
        return name
    }

    private var headline: String {
        if score == 0 { return firstName.map { L("Thanks for being honest, %@.", $0) } ?? L("Thanks for being honest.") }
        return firstName.map { L("Well done, %@!", $0) } ?? L("Well done!")
    }

    private var verdict: String {
        if score == total { return L("You know them all, even the hardest ones. But do you know the stories they tell?") }
        if score == 0 { return L("None yet. That's exactly why we're here.") }
        return L("The others still escape you. Not for long.")
    }

    var body: some View {
        ZStack {
            OnbScaffold(title: headline, spoken: true, onNext: onNext) {
                // The seven paintings fanned out: the named ones in color, the others dimmed.
                HStack(spacing: -36) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, item in
                        let known = user.profile.flashKnown.contains(item.id)
                        let spread = CGFloat(i) - CGFloat(cards.count - 1) / 2
                        ArtImage(name: item.image)
                            .saturation(known ? 1 : 0)
                            .opacity(known ? 1 : 0.55)
                            .frame(width: 78, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.bg, lineWidth: 3))
                            .overlay(alignment: .bottom) {
                                Image(systemName: known ? "checkmark" : "questionmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(known ? Palette.green : Color(hex: 0x2D2C2B)))
                                    .offset(y: 10)
                            }
                            .rotationEffect(.degrees(fanned ? Double(spread) * 6 : 0))
                            .offset(y: fanned ? abs(spread) * 8 : 0)
                            .shadow(color: Palette.blueDark.opacity(0.16), radius: 8, y: 4)
                            .zIndex(known ? 2 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .enter(2)

                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(count)")
                            .font(.figtree(72, .bold))
                            .foregroundStyle(Palette.blue)
                            .contentTransition(.numericText())
                        // L: shown after the big score number: "5 of 7", then "paintings named" below.
                        Text(L("of %@", "\(total)")).font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                    }
                    Text(score == 1 ? L("painting named") : L("paintings named"))
                        .font(.figtree(15, .semibold)).foregroundStyle(Palette.muted)
                    Text(verdict)
                        .font(.aBody).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                        .opacity(verdictShown ? 1 : 0)
                        .offset(y: verdictShown ? 0 : 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear(perform: play)
    }

    private func play() {
        withAnimation(.settle.delay(0.5)) { fanned = true }
        // The counter goes up one notch at a time, with a tick.
        for i in 0...score where i > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(i) * 0.22) {
                withAnimation(.easeOut(duration: 0.2)) { count = i }
                Haptics.rigid()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + Double(score) * 0.22) {
            withAnimation(.settle) { verdictShown = true }
            if score == 0 { Haptics.soft() }
        }
    }
}

// MARK: - What screen time adds up to, and what it can become

struct PhoneResultScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    /// Days shown: animated from 0 to the total, in a single motion.
    @State private var days: Double = 0
    @State private var stage = 0
    @State private var ticker: Timer?

    private var hours: Double { user.profile.phoneHours }
    private var target: Double { (hours * 365 / 24).rounded() }
    private let countDuration = 2.0

    private var monthsLine: String {
        let months = target / 30.4
        if months < 1.25 { return L("More than a full month, non-stop.") }
        return L("Nearly %@ full months, non-stop.", "\(Int(months.rounded()))")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            VStack(spacing: 4) {
                // L: "4h a day, over a year, adds up to", followed below by a big number and "days".
                Text(L("%@ a day, over a year, adds up to", formatHours(hours)))
                    .font(.figtree(18, .medium))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    CountingText(value: days)
                        .font(.figtree(104, .bold))
                        .foregroundStyle(Palette.ink)
                    Text(L("days"))
                        .font(.figtree(32, .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("%@ days", "\(Int(target))"))
            }
            .opacity(stage >= 1 ? 1 : 0)
            .offset(y: stage >= 1 ? 0 : 14)

            yearBar
                .padding(.top, 6)
                .opacity(stage >= 1 ? 1 : 0)

            Text(monthsLine)
                .font(.figtree(17, .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .opacity(stage >= 2 ? 1 : 0)
                .offset(y: stage >= 2 ? 0 : 10)

            Spacer(minLength: 16)

            // The turnaround: the Mona Lisa offers something else.
            MascotBubble(mascotSize: 84) {
                VStack(spacing: 6) {
                    Text(L("With me, that time can turn into knowledge."))
                        .font(.figtree(21, .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Five minutes a day is enough. Instead of doomscrolling, feed your mind with humanity's greatest works."))
                        .font(.figtree(15))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(stage >= 3 ? 1 : 0)
            .offset(y: stage >= 3 ? 0 : 26)

            Spacer(minLength: 16)

            // No button: a tap anywhere moves on, once everything has appeared.
            TapHint()
                .opacity(stage >= 4 ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .contentShape(Rectangle())
        .onTapGesture {
            guard stage >= 4 else { return }
            Haptics.tap()
            onNext()
        }
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: play)
        .onDisappear { ticker?.invalidate() }
    }

    /// The year in twelve months: the share spent on the phone fills in with the counter.
    private var yearBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    monthSegments.foregroundStyle(Palette.line)
                    ZStack(alignment: .leading) {
                        Color.clear
                        LinearGradient(colors: [Palette.yellow, Palette.orange], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * CGFloat(min(1, days / 365)))
                    }
                    .mask(monthSegments)
                }
            }
            .frame(height: 22)
            HStack(spacing: 4) {
                ForEach(Array(monthInitials.enumerated()), id: \.offset) { _, month in
                    Text(month)
                        .font(.figtree(11, .medium))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// "J", "F", "M"… in the app's language.
    private var monthInitials: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLanguage.locale
        return calendar.veryShortStandaloneMonthSymbols
    }

    private var monthSegments: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
            }
        }
    }

    private func play() {
        withAnimation(.settle.delay(0.35)) { stage = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // A single continuous motion: fast at the start, very gentle at the end.
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: countDuration)) { days = target }
            var beats = 0
            ticker?.invalidate()
            ticker = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { t in
                beats += 1
                Haptics.whisper()
                if Double(beats) * 0.09 >= countDuration * 0.7 { t.invalidate() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + countDuration * 0.8) {
            Haptics.heavy()
            withAnimation(.settle) { stage = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + countDuration + 0.5) {
            withAnimation(.settle) { stage = 3 }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + countDuration + 1.3) {
            withAnimation(.gentle) { stage = 4 }
        }
    }
}

// MARK: - In a year: nearly 400 paintings and artists

struct ProjectionScreen: View {
    let onNext: () -> Void

    @State private var value: Double = 0
    @State private var shown = 0
    @State private var detailShown = false
    /// True once the count and the detail line are in: the tap then moves on.
    @State private var done = false

    private let target: Double = 400
    private let countDuration = 2.4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // The paintings come in one by one and float around the number.
                FloatingSpace(shown: shown)

                VStack(spacing: 2) {
                    // L: followed below by a big counting number (400), then "paintings and artists".
                    Text(L("With Artura, in one year, you'll know nearly"))
                        .font(.figtree(20, .semibold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter()
                    CountingText(value: value)
                        .font(.figtree(112, .bold))
                        .foregroundStyle(Palette.blue)
                    Text(L("paintings and artists"))
                        .font(.figtree(28, .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(L("And not just their names: their stories, in detail."))
                        .font(.figtree(16))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .opacity(detailShown ? 1 : 0)
                        .offset(y: detailShown ? 0 : 10)
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 36)
                .background(
                    // A halo in the background color keeps the text readable in front of the paintings.
                    RadialGradient(colors: [Palette.bg, Palette.bg.opacity(0.94), Palette.bg.opacity(0)],
                                   center: .center, startRadius: 100, endRadius: 250)
                        .padding(-60)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("With Artura, in one year, you'll know nearly 400 paintings and artists. And not just their names: their stories, in detail."))
            }
            .frame(maxHeight: .infinity)

            // No button: a tap anywhere moves on, once the count is over.
            TapHint()
                .opacity(done ? 1 : 0)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .contentShape(Rectangle())
        .onTapGesture {
            guard done else { return }
            Haptics.tap()
            onNext()
        }
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: play)
    }

    private func play() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: countDuration)) { value = target }
        }
        for i in 1...FloatingSpace.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.14) {
                shown = max(shown, i)
                Haptics.whisper()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + countDuration * 0.85) {
            Haptics.heavy()
            withAnimation(.settle) { detailShown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + countDuration + 0.4) {
            withAnimation(.gentle) { done = true }
        }
    }
}

// MARK: - A few minutes a day changes everything (chart)

/// Progress curve: starts at the bottom left and rises to `lift` (fraction of the height) on the right.
struct GrowthCurve: Shape {
    let lift: CGFloat
    var closed = false

    static let startLift: CGFloat = 0.06

    static func y(_ lift: CGFloat, in rect: CGRect) -> CGFloat {
        rect.maxY - rect.height * lift
    }

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: rect.minX, y: Self.y(Self.startLift, in: rect))
        let end = CGPoint(x: rect.maxX, y: Self.y(lift, in: rect))
        var p = Path()
        p.move(to: start)
        p.addCurve(
            to: end,
            control1: CGPoint(x: rect.minX + rect.width * 0.45, y: start.y),
            control2: CGPoint(x: rect.minX + rect.width * 0.7, y: end.y + (start.y - end.y) * 0.3)
        )
        if closed {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
        return p
    }
}

struct GrowthChart: View {
    @State private var drawn = false
    @State private var ended = false

    private let withLift: CGFloat = 0.94
    private let withoutLift: CGFloat = 0.2
    private let inset: CGFloat = 10

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: inset, dy: inset)
                ZStack {
                    // Guide lines
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(i == 3 ? Palette.lip : Palette.line)
                            .frame(width: rect.width, height: i == 3 ? 2 : 1)
                            .position(x: rect.midX, y: rect.minY + rect.height * CGFloat(i) / 3)
                    }
                    GrowthCurve(lift: withLift, closed: true)
                        .fill(LinearGradient(colors: [Palette.yellow.opacity(0.34), Palette.yellow.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(inset)
                        .opacity(ended ? 1 : 0)
                    GrowthCurve(lift: withoutLift)
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(Palette.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 7]))
                        .padding(inset)
                    GrowthCurve(lift: withLift)
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(Palette.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(inset)

                    dot(Palette.blue)
                        .position(x: rect.minX, y: GrowthCurve.y(GrowthCurve.startLift, in: rect))
                    dot(Palette.yellow)
                        .scaleEffect(ended ? 1 : 0.3).opacity(ended ? 1 : 0)
                        .position(x: rect.maxX, y: GrowthCurve.y(withoutLift, in: rect))
                    dot(Palette.blue)
                        .scaleEffect(ended ? 1 : 0.3).opacity(ended ? 1 : 0)
                        .position(x: rect.maxX, y: GrowthCurve.y(withLift, in: rect))
                }
            }
            .frame(height: 122)

            HStack {
                Text(L("Today")).font(.aSmall).foregroundStyle(Palette.muted)
                Spacer()
                Text(L("In 1 year")).font(.figtree(14, .semibold)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, inset)

            HStack(spacing: 18) {
                legend(L("With Artura"), color: Palette.blue, dashed: false)
                legend(L("No routine"), color: Palette.yellow, dashed: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Chart: with Artura, your knowledge climbs steadily over a year; with no routine, it stays almost flat."))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.6)) { drawn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                withAnimation(.settle) { ended = true }
                Haptics.rigid()
            }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(Palette.bg)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(color, lineWidth: 4))
    }

    private func legend(_ text: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<(dashed ? 3 : 1), id: \.self) { _ in
                    Capsule().fill(color).frame(width: dashed ? 6 : 24, height: 4)
                }
            }
            Text(text).font(.aSmall).foregroundStyle(Palette.ink)
        }
    }
}

struct GraphScreen: View {
    let onNext: () -> Void

    // L: each line completes "With Artura, you develop…".
    private let gains = [L("your eye for art"), L("your general knowledge"), L("your conversation topics")]

    var body: some View {
        OnbScaffold(title: L("A few minutes a day changes everything."), spoken: true, mascotSize: 84, onNext: onNext) {
            GrowthChart()
                .enter(2)

            VStack(alignment: .leading, spacing: 0) {
                Text(L("With Artura, you develop"))
                    .font(.figtree(19, .semibold)).foregroundStyle(Palette.ink)
                    .padding(.bottom, 6)
                ForEach(Array(gains.enumerated()), id: \.offset) { i, gain in
                    HStack {
                        Text(gain).font(.aBody).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.orange)
                    }
                    .frame(height: 30)
                    .enter(Double(i) * 2 + 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
            .enter(4)
        }
    }
}

// MARK: - Streak: "Max, your learning starts today"

struct StreakScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var lit = false
    @State private var checked = false

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return L("%@, your learning starts today.", name)
        }
        return L("Your learning starts today.")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ArtImage(name: "ill_serie", zoom: lit ? 1.06 : 1, anchor: UnitPoint(x: 0.5, y: 0.6))
                    .frame(minHeight: 150, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .bottom) {
                        // The first-day flame, straddling the bottom of the image.
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.orange)
                            Text(L("Day 1"))
                                .font(.figtree(22, .bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(Capsule().fill(Palette.bg).shadow(color: Palette.blueDark.opacity(0.14), radius: 12, y: 6))
                        .scaleEffect(lit ? 1 : 0.6)
                        .opacity(lit ? 1 : 0)
                        .offset(y: 26)
                    }
                    .enter()

                VStack(spacing: 10) {
                    Text(title)
                        .font(.aTitle)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(3)
                    Text(L("Come back tomorrow to grow your streak."))
                        .font(.figtree(17))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(4.5)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 48)

                // The week: the first day gets checked.
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(day == 1 && checked ? Palette.yellow : Palette.bg)
                                Circle().stroke(day == 1 && checked ? Palette.yellow : Palette.lip, lineWidth: 1.5)
                                if day == 1 && checked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .frame(width: 34, height: 34)
                            // L: short for "Day 1", "Day 2"… under each circle of the week (keep it very short).
                            Text(L("D%@", "\(day)"))
                                .font(.figtree(12, day == 1 ? .bold : .regular))
                                .foregroundStyle(day == 1 ? Palette.ink : Palette.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
                .padding(.top, 22)
                .enter(6)

                Spacer(minLength: 16)

                Button(L("Continue")) { onNext() }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .onAppear {
            withAnimation(.settle.delay(0.5)) { lit = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.25)) { checked = true }
                Haptics.success()
            }
        }
    }
}
