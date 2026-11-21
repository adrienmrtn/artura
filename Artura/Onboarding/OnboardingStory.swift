import SwiftUI

// MARK: - Test: how many of these paintings can you name?

/// Entry test card. The last two are very hard on purpose.
struct FlashCard: Identifiable {
    let id: String
    let title: String
    let artist: String
    var hard = false
    var image: String { "art_\(id)" }

    static let all: [FlashCard] = [
        FlashCard(id: "joconde", title: "Mona Lisa", artist: "Leonardo da Vinci"),
        FlashCard(id: "nuit", title: "The Starry Night", artist: "Vincent van Gogh"),
        FlashCard(id: "vague", title: "The Great Wave off Kanagawa", artist: "Katsushika Hokusai"),
        FlashCard(id: "perle", title: "Girl with a Pearl Earring", artist: "Johannes Vermeer"),
        FlashCard(id: "baiser", title: "The Kiss", artist: "Gustav Klimt"),
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
                TagPill(text: "Painting \(min(index + 1, cards.count)) of \(cards.count)")
                Text("How many of these paintings can you name?")
                    .font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No cheating. Swipe the card, or use the buttons.")
                    .font(.aBody).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enter()

            // Card stack: the next one peeks out behind the top one.
            ZStack {
                ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { i, item in
                    if i <= index + 2 {
                        // An answered card stays off screen: it never comes back to the center.
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
                Button("Don't know") { answer(false) }.buttonStyle(.secondary)
                Button("I know it") { answer(true) }.buttonStyle(.primary)
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
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white, lineWidth: 5))
            .shadow(color: Palette.blueDark.opacity(0.16), radius: 12, y: 6)
            .overlay(alignment: .bottomLeading) {
                if item.hard { TagPill(text: "Expert level").padding(16) }
            }
            .overlay(alignment: .topLeading) {
                if top { stamp("I know it", Palette.green).opacity(stampOpacity(true)).padding(16) }
            }
            .overlay(alignment: .topTrailing) {
                if top { stamp("Don't know", Palette.ink).opacity(stampOpacity(false)).padding(16) }
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
        // The card exits on the answer's side while the next one rises, in the same animation.
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

// MARK: - Test result: "Nice work, Max!"

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
        if score == 0 { return firstName.map { "Thanks for being honest, \($0)." } ?? "Thanks for being honest." }
        return firstName.map { "Nice work, \($0)!" } ?? "Nice work!"
    }

    private var verdict: String {
        if score == total { return "You know them all, even the two toughest. But do you know the stories they tell?" }
        if score == 0 { return "None yet. That's exactly why we're here." }
        return "The rest still escape you. Not for long."
    }

    var body: some View {
        ZStack {
            OnbScaffold(title: headline, spoken: true, onNext: onNext) {
                // The seven paintings fanned out: named ones in color, the others dimmed.
                HStack(spacing: -36) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, item in
                        let known = user.profile.flashKnown.contains(item.id)
                        let spread = CGFloat(i) - CGFloat(cards.count - 1) / 2
                        ArtImage(name: item.image)
                            .saturation(known ? 1 : 0)
                            .opacity(known ? 1 : 0.55)
                            .frame(width: 78, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 3))
                            .overlay(alignment: .bottom) {
                                Image(systemName: known ? "checkmark" : "questionmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(known ? Palette.green : Palette.ink))
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
                        Text("of \(total)").font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                    }
                    Text(score == 1 ? "painting named" : "paintings named")
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
            if verdictShown && score > 0 { ConfettiView() }
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

    @State private var days = 0
    @State private var stage = 0
    @State private var timer: Timer?

    private var hours: Double { user.profile.phoneHours }
    private var target: Int { Int((hours * 365 / 24).rounded()) }

    private var monthsLine: String {
        let months = Double(target) / 30.4
        if months < 1.25 { return "More than a whole month, every year." }
        let whole = Int(months.rounded())
        return "Nearly \(whole) whole month\(whole == 1 ? "" : "s"), every year."
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text("\(formatHours(hours)) a day on your phone adds up to")
                    .font(.figtree(17, .medium))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(stage >= 1 ? 1 : 0)
                Text("\(days)")
                    .font(.figtree(112, .bold))
                    .foregroundStyle(Palette.orange)
                    .contentTransition(.numericText())
                    .opacity(stage >= 2 ? 1 : 0)
                Text("days a year")
                    .font(.figtree(28, .semibold))
                    .foregroundStyle(Palette.ink)
                    .opacity(stage >= 2 ? 1 : 0)
                Text(monthsLine)
                    .font(.aBody)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 8)
                    .opacity(stage >= 3 ? 1 : 0)
            }
            .multilineTextAlignment(.center)

            Spacer(minLength: 16)

            // The turnaround: that time can go toward something else.
            VStack(spacing: 10) {
                Text("With Artura, that time can become knowledge.")
                    .font(.figtree(26, .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Instead of scrolling endlessly, feed your mind with humanity's greatest artworks. Five minutes is all it takes.")
                    .font(.aBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.sandLight))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.sand, lineWidth: 1))
            .opacity(stage >= 4 ? 1 : 0)
            .offset(y: stage >= 4 ? 0 : 20)

            Spacer(minLength: 16)

            Button("Continue") { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .onAppear(perform: play)
        .onDisappear { timer?.invalidate() }
    }

    private func play() {
        withAnimation(.settle.delay(0.3)) { stage = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) { stage = 2 }
            // The counter climbs to the total, with a tick at each step.
            let stepCount = 32
            var step = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { t in
                step += 1
                let progress = 1 - pow(1 - Double(step) / Double(stepCount), 2)
                withAnimation(.linear(duration: 0.045)) {
                    days = Int((Double(target) * progress).rounded())
                }
                if step % 3 == 0 { Haptics.whisper() }
                if step >= stepCount {
                    t.invalidate()
                    days = target
                    Haptics.heavy()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            withAnimation(.settle) { stage = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.settle) { stage = 4 }
            Haptics.soft()
        }
    }
}

// MARK: - In a year: nearly 400 paintings

struct ProjectionScreen: View {
    let onNext: () -> Void

    @State private var count = 0
    @State private var detailShown = false
    @State private var timer: Timer?

    private let target = 400
    private let columns = 25
    private let rows = 16

    var body: some View {
        VStack(spacing: 0) {
            Text("With Artura, a year from now, you'll know nearly")
                .font(.figtree(22, .medium)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .enter()

            Text("\(count)")
                .font(.figtree(104, .bold))
                .foregroundStyle(Palette.blue)
                .contentTransition(.numericText())
                .padding(.top, 2)
            Text("paintings")
                .font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)

            // One square per painting: the grid fills in step with the counter.
            Canvas { context, size in
                let gap: CGFloat = 3
                let cell = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
                for i in 0..<(columns * rows) {
                    let x = CGFloat(i % columns) * (cell + gap)
                    let y = CGFloat(i / columns) * (cell + gap)
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    let path = Path(roundedRect: rect, cornerRadius: 2.5)
                    // A few golden squares for depth, like frames.
                    let filled = i < count
                    let color = !filled ? Palette.line : (i % 7 == 3 ? Palette.yellow : Palette.blue)
                    context.fill(path, with: .color(color))
                }
            }
            .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
            .padding(.top, 22)
            .enter(2)
            .accessibilityHidden(true)

            Text("And not just by name: you'll know them inside out.")
                .font(.figtree(17)).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .opacity(detailShown ? 1 : 0)
                .offset(y: detailShown ? 0 : 12)

            Spacer(minLength: 16)

            Button("Continue") { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
        .onAppear(perform: play)
        .onDisappear { timer?.invalidate() }
    }

    private func play() {
        timer?.invalidate()
        count = 0
        let stepCount = 50
        var step = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            timer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { t in
                step += 1
                // Fast start, gentle finish.
                let progress = 1 - pow(1 - Double(step) / Double(stepCount), 2)
                withAnimation(.linear(duration: 0.035)) {
                    count = min(target, Int((Double(target) * progress).rounded()))
                }
                if step % 3 == 0 { Haptics.whisper() }
                if step >= stepCount {
                    t.invalidate()
                    count = target
                    Haptics.heavy()
                    withAnimation(.settle.delay(0.15)) { detailShown = true }
                }
            }
        }
    }
}

// MARK: - A few minutes a day changes everything (curve)

/// Progress curve: starts bottom left and rises to `lift` (fraction of the height) on the right.
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
                Text("Today").font(.aSmall).foregroundStyle(Palette.muted)
                Spacer()
                Text("In 1 year").font(.figtree(14, .semibold)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, inset)

            HStack(spacing: 18) {
                legend("With Artura", color: Palette.blue, dashed: false)
                legend("No routine", color: Palette.yellow, dashed: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chart: with Artura, your knowledge climbs sharply in a year; with no routine, it stays almost flat.")
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
            .fill(.white)
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

    private let gains = ["your eye for art", "your general knowledge", "your conversation starters"]

    var body: some View {
        OnbScaffold(title: "A few minutes a day changes everything.", spoken: true, mascotSize: 84, onNext: onNext) {
            GrowthChart()
                .enter(2)

            VStack(alignment: .leading, spacing: 0) {
                Text("With Artura, you build")
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
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
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
            return "\(name), your learning starts today."
        }
        return "Your learning starts today."
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ArtImage(name: "ill_serie", zoom: lit ? 1.06 : 1, anchor: UnitPoint(x: 0.5, y: 0.6))
                    .frame(minHeight: 150, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .bottom) {
                        // The day-one flame, straddling the bottom edge of the image.
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.orange)
                            Text("Day 1")
                                .font(.figtree(22, .bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(Capsule().fill(.white).shadow(color: Palette.blueDark.opacity(0.14), radius: 12, y: 6))
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
                    Text("Come back tomorrow to grow your streak.")
                        .font(.figtree(17))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(4.5)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 48)

                // The week: day one gets checked off.
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
                            Text("Day \(day)")
                                .font(.figtree(12, day == 1 ? .bold : .regular))
                                .foregroundStyle(day == 1 ? Palette.ink : Palette.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
                .padding(.top, 22)
                .enter(6)

                Spacer(minLength: 16)

                Button("Continue") { onNext() }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)

            if checked { ConfettiView() }
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
