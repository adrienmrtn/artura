import SwiftUI

// MARK: - Slow screen: no button, tap to continue once the animation is done

struct SlowScreen<Content: View>: View {
    /// Animation duration, in seconds. Tapping the screen does nothing before it ends.
    let duration: Double
    var dark: Bool = false
    let onNext: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var ready = false
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .bottom) {
            (dark ? Color(hex: 0x171514) : Color.white).ignoresSafeArea()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Text("Tap to continue")
                .font(.figtree(14, .medium))
                .foregroundStyle(dark ? Color.white.opacity(0.8) : Palette.muted)
                .opacity(ready ? (pulse ? 1 : 0.45) : 0)
                .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard ready else {
                Haptics.whisper()
                return
            }
            Haptics.press()
            onNext()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to continue")
        .task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.6)) { ready = true }
            Haptics.soft()
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Quotes: a single screen, they appear one by one

struct Quote: Identifiable {
    let image: String
    let text: String
    let author: String
    let role: String
    var id: String { author }

    // Quotes to be verified (source and translation) before launch.
    static let all: [Quote] = [
        Quote(image: "portrait_klee", text: "Art does not reproduce the visible; it makes visible.", author: "Paul Klee", role: "Painter"),
        Quote(image: "portrait_nietzsche", text: "We have art so that we shall not die of the truth.", author: "Friedrich Nietzsche", role: "Philosopher"),
        Quote(image: "portrait_proust", text: "Through art alone are we able to emerge from ourselves.", author: "Marcel Proust", role: "Writer"),
        Quote(image: "portrait_malraux", text: "Art is an anti-destiny.", author: "André Malraux", role: "Writer"),
        Quote(image: "portrait_wilde", text: "Life imitates art far more than art imitates life.", author: "Oscar Wilde", role: "Writer")
    ]
}

struct QuotesScreen: View {
    let onNext: () -> Void
    @State private var shown = 0
    @State private var pulse = false

    private let quotes = Quote.all
    private var allShown: Bool { shown >= quotes.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x171514).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                    HStack(alignment: .top, spacing: 14) {
                        ArtImage(name: quote.image, anchor: .top)
                            .saturation(0)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("“\(quote.text)”")
                                .font(.figtree(18, .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(quote.author) · \(quote.role)")
                                .font(.figtree(13))
                                .foregroundStyle(Color.white.opacity(0.75))
                        }
                    }
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown ? 0 : 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Text(allShown ? "Tap to continue" : "Tap for the next one")
                .font(.figtree(14, .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .opacity(shown == 0 ? 0 : (pulse ? 1 : 0.45))
                .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(allShown ? "Tap to continue" : "Tap to show the next quote")
        .onAppear {
            // The first quote appears on its own; the next ones on tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if shown == 0 { reveal() }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    private func advance() {
        if allShown {
            Haptics.press()
            onNext()
        } else {
            reveal()
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.7)) { shown += 1 }
        Haptics.soft()
    }
}

// MARK: - Quick test: 5 stacked masterpieces, yes or no

struct FlashTestScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    static let ids = ["joconde", "nuit", "vague", "perle", "baiser"]

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var armed = false
    @State private var known: [String] = []
    /// Cards already answered and the side they left from.
    @State private var gone: [String: CGFloat] = [:]

    private var cards: [Artwork] { Self.ids.compactMap { content.artwork($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.pressable)
                .padding(.leading, -12)
                .accessibilityLabel("Back")
                ProgressTrack(value: Double(index) / Double(max(1, cards.count)))
                Text("\(min(index + 1, cards.count)) / \(cards.count)")
                    .font(.figtree(14, .medium)).foregroundStyle(Palette.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                TagPill(text: "Quick test · 10 seconds")
                Text("Recognize it?").font(.aTitle).foregroundStyle(Palette.ink)
                Text("No cheating. Swipe the card, or use the buttons.")
                    .font(.aBody).foregroundStyle(Palette.muted)
            }

            // Card stack: the next one peeks out behind the top one.
            ZStack {
                ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { i, art in
                    if i <= index + 2 {
                        // An answered card stays off screen: it never comes back to the center.
                        let depth = max(0, i - index)
                        let exit = gone[art.id]
                        let x = exit ?? (i == index ? drag.width : 0)
                        card(art, top: i == index)
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

            HStack(spacing: 12) {
                Button("No") { answer(false) }.buttonStyle(.secondary)
                Button("Yes") { answer(true) }.buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
    }

    private func card(_ art: Artwork, top: Bool) -> some View {
        ArtImage(name: art.image)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 4))
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
            .overlay(alignment: .topLeading) {
                if top { stamp("Yes", Palette.green).opacity(stampOpacity(true)).padding(16) }
            }
            .overlay(alignment: .topTrailing) {
                if top { stamp("No", Palette.ink).opacity(stampOpacity(false)).padding(16) }
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
            .font(.figtree(22, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
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

// MARK: - Quick test result

struct FlashResultScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var count = 0
    @State private var fanned = false
    @State private var statShown = false
    @State private var ready = false

    private var cards: [Artwork] { FlashTestScreen.ids.compactMap { content.artwork($0) } }
    private var total: Int { cards.count }
    private var score: Int { user.profile.flashKnown.count }

    private var verdict: String {
        if score == total { return "You know them all. But do you know their stories?" }
        if score == 0 { return "None yet. That's exactly why we're here." }
        return "The others still escape you. Not for long."
    }

    var body: some View {
        VStack(spacing: 0) {
            // The five artworks fanned out: recognized ones in color, the others dimmed.
            ZStack {
                Palette.blueSoft
                HStack(spacing: -34) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, art in
                        let known = user.profile.flashKnown.contains(art.id)
                        ArtImage(name: art.image)
                            .saturation(known ? 1 : 0)
                            .opacity(known ? 1 : 0.55)
                            .frame(width: 96, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 3))
                            .overlay(alignment: .bottom) {
                                Image(systemName: known ? "checkmark" : "questionmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(known ? Palette.green : Palette.ink))
                                    .offset(y: 10)
                            }
                            .rotationEffect(.degrees(fanned ? Double(i - 2) * 7 : 0))
                            .offset(y: fanned ? abs(CGFloat(i - 2)) * 10 : 0)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            .zIndex(known ? 2 : 1)
                    }
                }
                .padding(.top, 40)
            }
            .frame(height: 290)
            .clipShape(ArcHeaderShape())
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .topLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Back")
                .padding(.leading, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(count)")
                        .font(.figtree(72, .semibold))
                        .foregroundStyle(Palette.blue)
                        .contentTransition(.numericText())
                    Text("out of \(total)").font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                }
                Text(score == 1 ? "artwork recognized" : "artworks recognized")
                    .font(.figtree(15, .semibold)).foregroundStyle(Palette.muted)
                Text(verdict)
                    .font(.aBody).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .opacity(fanned ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, -34)

            Spacer(minLength: 12)

            // Statistic to be sourced precisely before launch
            // (study on time spent in front of artworks, Art Institute of Chicago, 2017).
            HStack(spacing: 0) {
                ArtImage(name: "ill_regard", anchor: UnitPoint(x: 0.5, y: 0.6))
                    .frame(width: 118)
                VStack(alignment: .leading, spacing: 4) {
                    Text("28 seconds").font(.figtree(26, .semibold)).foregroundStyle(.white)
                    Text("That's the average time spent with an artwork in a museum. Recognizing isn't looking. Not yet.")
                        .font(.figtree(13)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Art Institute of Chicago, 2017").font(.figtree(11)).foregroundStyle(Color.white.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                Spacer(minLength: 0)
            }
            .frame(height: 148)
            .background(Color(hex: 0x1E2A5A))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .opacity(statShown ? 1 : 0)
            .offset(y: statShown ? 0 : 16)

            Button("Continue") { onNext() }
                .buttonStyle(.primary)
                .disabled(!ready)
                .opacity(ready ? 1 : 0.4)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear(perform: play)
    }

    private func play() {
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) { fanned = true }
        let steps = max(1, score)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.4) {
                withAnimation(.easeOut(duration: 0.3)) { count = min(i, score) }
                Haptics.rigid()
            }
        }
        let afterCount = 1.3 + Double(steps) * 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCount) {
            withAnimation(.easeOut(duration: 0.9)) { statShown = true }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCount + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) { ready = true }
        }
    }
}

// MARK: - Time spent on your phone (the question)

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var hours: Double = 4
    @State private var glow = false

    private var hoursLabel: String {
        let whole = Int(hours)
        return hours == Double(whole) ? "\(whole)h" : "\(whole)h 30"
    }

    var body: some View {
        OnbScaffold(number: OnbStep.phoneTime.number, onBack: onBack,
                    title: "How much time a day do you spend on your phone?",
                    subtitle: "Not sure? Check Settings › Screen Time.",
                    onNext: save) {
            ArtImage(name: "ill_phone", zoom: glow ? 1.08 : 1, anchor: UnitPoint(x: 0.5, y: 0.45))
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 0) {
                Text(hoursLabel)
                    .font(.figtree(52, .semibold)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("a day").font(.aBody).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Slider(value: $hours, in: 1...10, step: 0.5)
                    .tint(Palette.blue)
                    .accessibilityLabel("Hours a day on your phone")
                HStack {
                    Text("1h"); Spacer(); Text("5h"); Spacer(); Text("10h")
                }
                .font(.aCaption).foregroundStyle(Palette.muted)
            }
        }
        .onAppear {
            hours = user.profile.phoneHours
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { glow = true }
        }
        .onChange(of: hours) { _, _ in Haptics.selection() }
    }

    private func save() {
        user.profile.phoneHours = hours
        onNext()
    }
}

// MARK: - What it adds up to over a year (slow screen)

struct PhoneResultScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var days = 0
    @State private var stage = 0
    @State private var timer: Timer?

    private var hours: Double { user.profile.phoneHours }
    private var target: Int { Int((hours * 365 / 24).rounded()) }

    private var hoursLabel: String {
        let whole = Int(hours)
        return hours == Double(whole) ? "\(whole)h" : "\(whole)h 30"
    }

    private var monthsLine: String {
        let months = Double(target) / 30.4
        let rounded = Int(months.rounded())
        if months < 1.25 || rounded < 2 { return "More than a full month, every year." }
        return "Nearly \(rounded) full months, every year."
    }

    var body: some View {
        SlowScreen(duration: 6.2, dark: true, onNext: onNext) {
            VStack(spacing: 14) {
                Spacer()
                Text("\(hoursLabel) a day adds up to")
                    .font(.figtree(22, .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .opacity(stage >= 1 ? 1 : 0)
                Text("\(days)")
                    .font(.figtree(120, .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .opacity(stage >= 2 ? 1 : 0)
                Text("days a year")
                    .font(.figtree(28, .semibold))
                    .foregroundStyle(.white)
                    .opacity(stage >= 2 ? 1 : 0)
                Text(monthsLine)
                    .font(.aBody)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .opacity(stage >= 3 ? 1 : 0)
                    .padding(.top, 6)
                Spacer()
                Text("Artura asks for just five minutes.")
                    .font(.figtree(20, .semibold))
                    .foregroundStyle(Palette.yellow)
                    .opacity(stage >= 4 ? 1 : 0)
                    .offset(y: stage >= 4 ? 0 : 12)
                Spacer()
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
        }
        .onAppear(perform: play)
        .onDisappear { timer?.invalidate() }
    }

    private func play() {
        withAnimation(.easeOut(duration: 0.9).delay(0.3)) { stage = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.6)) { stage = 2 }
            // The counter climbs slowly to the total, with a tick at each step.
            let stepCount = 40
            var step = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { t in
                step += 1
                withAnimation(.linear(duration: 0.06)) {
                    days = Int((Double(target) * Double(step) / Double(stepCount)).rounded())
                }
                if step % 3 == 0 { Haptics.whisper() }
                if step >= stepCount {
                    t.invalidate()
                    days = target
                    Haptics.heavy()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeOut(duration: 0.8)) { stage = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
            withAnimation(.easeOut(duration: 0.8)) { stage = 4 }
            Haptics.soft()
        }
    }
}

// MARK: - "Art gives it back" (slow text, tap to continue)

struct StatementScreen: View {
    let onNext: () -> Void
    @State private var line = 0

    private let lines = [
        "Your phone takes your attention.",
        "Art gives it back.",
        "A painting doesn't scroll. It waits for you."
    ]

    var body: some View {
        SlowScreen(duration: 1.0 + Double(lines.count) * 1.5, onNext: onNext) {
            VStack(alignment: .leading, spacing: 26) {
                Spacer()
                ForEach(Array(lines.enumerated()), id: \.offset) { i, text in
                    Text(text)
                        .font(.figtree(i == 1 ? 40 : 28, .semibold))
                        .foregroundStyle(i == 1 ? Palette.blue : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(i < line ? 1 : 0)
                        .offset(y: i < line ? 0 : 14)
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
        }
        .onAppear {
            for i in 1...lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i - 1) * 1.5) {
                    withAnimation(.easeOut(duration: 1.0)) { line = i }
                    if i == 2 { Haptics.heavy() } else { Haptics.soft() }
                }
            }
        }
    }
}

// MARK: - What's left to us

struct WhatRemainsScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_reste", onBack: onBack, onNext: onNext) {
            TagPill(text: "What's left to us").appearUp(0.1)
            Text("Machines make. Looking is up to you.")
                .font(.figtree(30, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("An image can now be made in seconds. Knowing why one moves you and another doesn't? That can't be outsourced.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
            Text("Taste takes practice. We start today.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.4)
        }
    }
}

// MARK: - Your arts

struct ArtsScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let arts: [(id: String, title: String, image: String, soon: Bool)] = [
        ("peinture", "Painting", "ill_palette", false),
        ("sculpture", "Sculpture", "ill_sculpture", true),
        ("architecture", "Architecture", "ill_musee", true),
        ("photographie", "Photography", "ill_photo", true)
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.arts.number, onBack: onBack, title: "Which arts do you want to explore?",
                    subtitle: "As many as you like. Painting is ready, the others are on the way.",
                    ctaEnabled: !user.profile.arts.isEmpty, onNext: onNext) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(arts.enumerated()), id: \.element.id) { i, art in
                    let selected = user.profile.arts.contains(art.id)
                    Button {
                        Haptics.selection()
                        if let at = user.profile.arts.firstIndex(of: art.id) {
                            user.profile.arts.remove(at: at)
                        } else {
                            user.profile.arts.append(art.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ArtImage(name: art.image).frame(height: 120)
                            HStack(spacing: 6) {
                                Text(art.title).font(.bodyStrong).foregroundStyle(Palette.ink)
                                if art.soon {
                                    Text("Soon").font(.figtree(11, .semibold)).foregroundStyle(Palette.muted)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(.white))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .background(selected ? Palette.blueSelected : Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
                        .overlay(alignment: .topTrailing) {
                            if selected { CheckBadge().padding(8).transition(.opacity) }
                        }
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .appearUp(0.06 * Double(i))
                }
            }
        }
    }
}

// MARK: - Commitment: long press

struct CommitScreen: View {
    let onNext: () -> Void

    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var done = false
    @State private var ticker: Timer?

    private let holdDuration = 2.2

    var body: some View {
        VStack(spacing: 18) {
            ArtImage(name: "ill_engagement", anchor: UnitPoint(x: 0.5, y: 0.6))
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.top, 12)
            Spacer(minLength: 0)
            Text("One artwork a day.")
                .font(.figtree(34, .semibold)).foregroundStyle(Palette.ink)
            Text("Five minutes, every day. Not to impress anyone. Just for you.")
                .font(.aBody).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(Palette.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(done ? Palette.green : Palette.blue).padding(18)
                    .scaleEffect(pressing ? 0.94 : 1)
                Image(systemName: done ? "checkmark" : "hand.tap.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 160, height: 160)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 80) {
                complete()
            } onPressingChanged: { isPressing in
                guard !done else { return }
                pressing = isPressing
                if isPressing {
                    start()
                } else {
                    cancel()
                }
            }
            .accessibilityLabel("Hold to commit")
            .accessibilityAddTraits(.isButton)

            Text(done ? "Here we go." : "Press and hold to commit")
                .font(.figtree(15, .semibold))
                .foregroundStyle(done ? Palette.green : Palette.ink)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onDisappear { ticker?.invalidate() }
    }

    private func start() {
        withAnimation(.linear(duration: holdDuration)) { progress = 1 }
        var beat = 0
        ticker?.invalidate()
        // The vibration grows stronger while pressing.
        ticker = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { _ in
            beat += 1
            Haptics.rise(min(1, 0.25 + Double(beat) * 0.04))
        }
    }

    private func cancel() {
        ticker?.invalidate()
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }

    private func complete() {
        ticker?.invalidate()
        done = true
        pressing = false
        progress = 1
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onNext() }
    }
}
