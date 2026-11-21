import SwiftUI

// MARK: - Écran lent : pas de bouton, on touche pour continuer une fois l'animation finie

struct SlowScreen<Content: View>: View {
    /// Durée de l'animation, en secondes. Avant la fin, toucher l'écran ne fait rien.
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
            Text("Touche pour continuer")
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
        .accessibilityHint("Touche pour continuer")
        .task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.6)) { ready = true }
            Haptics.soft()
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Citation plein écran

struct Quote {
    let image: String
    let text: String
    let author: String
    let role: String

    // Citations à faire vérifier (source et traduction) avant la mise en ligne.
    static let klee = Quote(image: "portrait_klee", text: "L'art ne reproduit pas le visible, il rend visible.", author: "Paul Klee", role: "Peintre")
    static let nietzsche = Quote(image: "portrait_nietzsche", text: "Nous avons l'art pour ne pas mourir de la vérité.", author: "Friedrich Nietzsche", role: "Philosophe")
    static let proust = Quote(image: "portrait_proust", text: "Par l'art seulement, nous pouvons sortir de nous.", author: "Marcel Proust", role: "Écrivain")
    static let malraux = Quote(image: "portrait_malraux", text: "L'art est un anti-destin.", author: "André Malraux", role: "Écrivain")
    static let wilde = Quote(image: "portrait_wilde", text: "La vie imite l'art bien plus que l'art n'imite la vie.", author: "Oscar Wilde", role: "Écrivain")
}

struct QuoteScreen: View {
    let quote: Quote
    let onNext: () -> Void

    @State private var portraitShown = false
    @State private var revealed = 0
    @State private var signed = false

    private var words: [String] {
        ("« " + quote.text + " »").split(separator: " ").map(String.init)
    }

    private var duration: Double { 1.8 + Double(words.count) * 0.2 + 0.9 }

    var body: some View {
        SlowScreen(duration: duration, dark: true, onNext: onNext) {
            VStack(alignment: .leading, spacing: 24) {
                ArtImage(name: quote.image, anchor: .top)
                    .saturation(0)
                    .scaleEffect(portraitShown ? 1 : 1.08)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .opacity(portraitShown ? 1 : 0)

                FlowLayout(spacing: 7) {
                    ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                        Text(word)
                            .font(.figtree(27, .semibold))
                            .foregroundStyle(.white)
                            .opacity(i < revealed ? 1 : 0)
                            .offset(y: i < revealed ? 0 : 6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.author).font(.figtree(17, .semibold)).foregroundStyle(.white)
                    Text(quote.role).font(.figtree(14)).foregroundStyle(Color.white.opacity(0.75))
                }
                .opacity(signed ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .onAppear(perform: play)
    }

    private func play() {
        withAnimation(.easeOut(duration: 1.8)) { portraitShown = true }
        for i in 1...words.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4 + Double(i) * 0.2) {
                withAnimation(.easeOut(duration: 0.5)) { revealed = i }
                Haptics.whisper()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4 + Double(words.count) * 0.2 + 0.4) {
            withAnimation(.easeOut(duration: 0.7)) { signed = true }
        }
    }
}

// MARK: - Test éclair : 5 chefs-d'œuvre, « tu le reconnais ? »

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

    private var cards: [Artwork] { Self.ids.compactMap { content.artwork($0) } }
    private var current: Artwork? { cards.indices.contains(index) ? cards[index] : nil }

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
                .accessibilityLabel("Retour")
                ProgressTrack(value: Double(index) / Double(max(1, cards.count)))
                Text("\(min(index + 1, cards.count)) / \(cards.count)")
                    .font(.figtree(14, .medium)).foregroundStyle(Palette.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                TagPill(text: "Test éclair · 10 secondes")
                Text("Tu la reconnais ?").font(.aTitle).foregroundStyle(Palette.ink)
                Text("Sans tricher. Glisse à droite si oui, à gauche si non.")
                    .font(.aBody).foregroundStyle(Palette.muted)
            }

            ZStack {
                if cards.indices.contains(index + 1) {
                    ArtImage(name: cards[index + 1].image)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .scaleEffect(0.95)
                        .opacity(0.5)
                }
                if let current {
                    ArtImage(name: current.image)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .topLeading) { stamp("Je connais", Palette.green).opacity(stampOpacity(true)).padding(14) }
                        .overlay(alignment: .topTrailing) { stamp("Jamais vue", Palette.ink).opacity(stampOpacity(false)).padding(14) }
                        .offset(x: drag.width, y: drag.height * 0.15)
                        .rotationEffect(.degrees(Double(drag.width) / 22))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    drag = value.translation
                                    let nowArmed = abs(value.translation.width) > 90
                                    if nowArmed != armed {
                                        armed = nowArmed
                                        Haptics.selection()
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width > 90 {
                                        answer(true)
                                    } else if value.translation.width < -90 {
                                        answer(false)
                                    } else {
                                        withAnimation(.snappy) { drag = .zero }
                                    }
                                }
                        )
                        .id(current.id)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button("Jamais vue") { answer(false) }.buttonStyle(.secondary)
                Button("Je connais") { answer(true) }.buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
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
        guard let current else { return }
        armed = false
        if knows {
            known.append(current.id)
            Haptics.success()
        } else {
            Haptics.rigid()
        }
        if index >= cards.count - 1 {
            user.profile.flashKnown = known
            onNext()
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                drag = .zero
                index += 1
            }
        }
    }
}

// MARK: - Résultat du test éclair

struct FlashResultScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var count = 0
    @State private var ready = false

    private var total: Int { FlashTestScreen.ids.count }
    private var score: Int { user.profile.flashKnown.count }
    private var missed: [Artwork] {
        FlashTestScreen.ids.filter { !user.profile.flashKnown.contains($0) }.compactMap { content.artwork($0) }
    }

    private var verdict: String {
        if score == total { return "Tu les reconnais toutes. Mais sais-tu ce qu'elles racontent ?" }
        if score == 0 { return "Aucune pour l'instant. C'est exactement pour ça qu'on est là." }
        return "Voici ce qui t'échappe encore."
    }

    var body: some View {
        OnbScaffold(number: OnbStep.flashResult.number, onBack: onBack,
                    title: "\(count) sur \(total)", subtitle: verdict,
                    ctaEnabled: ready, onNext: onNext) {
            if !missed.isEmpty {
                HStack(spacing: 10) {
                    ForEach(missed) { art in
                        VStack(alignment: .leading, spacing: 4) {
                            ArtImage(name: art.image)
                                .frame(height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(art.title).font(.figtree(11, .medium)).foregroundStyle(Palette.muted)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .opacity(ready ? 1 : 0)
            }

            // Statistique à sourcer précisément avant la mise en ligne
            // (étude sur le temps passé devant les œuvres, Art Institute of Chicago, 2017).
            VStack(alignment: .leading, spacing: 6) {
                Text("28 secondes").font(.figtree(34, .semibold)).foregroundStyle(Palette.ink)
                Text("C'est le temps moyen passé devant une œuvre dans un musée. Reconnaître une image n'est pas encore la regarder.")
                    .font(.aSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Étude menée à l'Art Institute of Chicago, 2017").font(.figtree(11)).foregroundStyle(Palette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.blueSoft))
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 10)
        }
        .onAppear(perform: play)
    }

    private func play() {
        let steps = max(1, score)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.35) {
                withAnimation(.easeOut(duration: 0.3)) { count = min(i, score) }
                Haptics.rigid()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(steps) * 0.35) {
            withAnimation(.easeOut(duration: 0.7)) { ready = true }
            Haptics.soft()
        }
    }
}

// MARK: - Le temps passé sur ton téléphone

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var hours: Double = 4
    @State private var pull = false

    /// Jours entiers par an que représentent ces heures quotidiennes.
    private var daysPerYear: Int { Int((hours * 365 / 24).rounded()) }

    private var hoursLabel: String {
        let whole = Int(hours)
        return hours == Double(whole) ? "\(whole) h" : "\(whole) h 30"
    }

    var body: some View {
        OnbScaffold(number: OnbStep.phoneTime.number, onBack: onBack,
                    title: "Combien de temps par jour sur ton téléphone ?",
                    subtitle: "Regarde dans Réglages › Temps d'écran si tu hésites.",
                    onNext: save) {
            ArtImage(name: "ill_phone", zoom: pull ? 1.12 : 1, anchor: UnitPoint(x: 0.45, y: 0.4))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 2) {
                Text(hoursLabel).font(.figtree(22, .semibold)).foregroundStyle(Palette.muted)
                    .contentTransition(.numericText())
                Text("\(daysPerYear) jours par an")
                    .font(.figtree(40, .semibold)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("passés les yeux sur l'écran, jour et nuit compris.")
                    .font(.aSmall).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Slider(value: $hours, in: 1...10, step: 0.5)
                    .tint(Palette.blue)
                    .accessibilityLabel("Heures par jour sur ton téléphone")
                HStack {
                    Text("1 h"); Spacer(); Text("5 h"); Spacer(); Text("10 h")
                }
                .font(.aCaption).foregroundStyle(Palette.muted)
            }

            Text("Artura t'en demande cinq minutes.")
                .font(.bodyStrong).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            hours = user.profile.phoneHours
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { pull = true }
        }
        .onChange(of: hours) { _, _ in Haptics.selection() }
    }

    private func save() {
        user.profile.phoneHours = hours
        onNext()
    }
}

// MARK: - « L'art te la rend » (texte lent, toucher pour continuer)

struct StatementScreen: View {
    let onNext: () -> Void
    @State private var line = 0

    private let lines = [
        "Ton téléphone prend ton attention.",
        "L'art te la rend.",
        "Un tableau ne défile pas. Il t'attend."
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

// MARK: - Ce qui nous reste

struct WhatRemainsScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_reste", onBack: onBack, onNext: onNext) {
            TagPill(text: "Ce qui nous reste").appearUp(0.1)
            Text("Les machines produisent. Regarder, c'est toi.")
                .font(.figtree(30, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Une image se fabrique maintenant en quelques secondes. Savoir pourquoi l'une te touche et pas l'autre, ça ne se délègue pas.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
            Text("Le goût se travaille. On commence aujourd'hui.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.4)
        }
    }
}

// MARK: - Tes arts

struct ArtsScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let arts: [(id: String, title: String, image: String, soon: Bool)] = [
        ("peinture", "Peinture", "ill_palette", false),
        ("sculpture", "Sculpture", "ill_sculpture", true),
        ("architecture", "Architecture", "ill_musee", true),
        ("photographie", "Photographie", "ill_photo", true)
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.arts.number, onBack: onBack, title: "Quels arts veux-tu explorer ?",
                    subtitle: "Autant que tu veux. La peinture est prête, les autres arrivent.",
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
                                    Text("Bientôt").font(.figtree(11, .semibold)).foregroundStyle(Palette.muted)
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

// MARK: - La carte des courants

struct MapScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var shown = 0
    @State private var ready = false

    private var startID: String? {
        user.profile.movements.first ?? content.movements.first?.id
    }

    var body: some View {
        OnbScaffold(number: OnbStep.map.number, onBack: onBack, title: "Voici ta carte",
                    subtitle: "\(content.movements.count) courants, \(content.artworks.count) œuvres pour commencer. Tu les débloques un par un.",
                    ctaEnabled: ready, onNext: onNext) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(content.movements.enumerated()), id: \.element.id) { i, movement in
                        let isStart = movement.id == startID
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle().fill(isStart ? Palette.blue : Palette.card)
                                    Image(systemName: isStart ? "play.fill" : "lock.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isStart ? .white : Palette.muted)
                                }
                                .frame(width: 44, height: 44)
                                if i < content.movements.count - 1 {
                                    Rectangle().fill(Palette.line).frame(width: 4, height: 30)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(movement.name).font(.bodyStrong).foregroundStyle(Palette.ink)
                                Text(isStart ? "Tu commences ici" : movement.period)
                                    .font(.aCaption)
                                    .foregroundStyle(isStart ? Palette.blueText : Palette.muted)
                            }
                            .padding(.top, 4)
                            Spacer(minLength: 0)
                        }
                        .opacity(i < shown ? 1 : 0)
                        .offset(x: i < shown ? 0 : -10)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: play)
    }

    private func play() {
        let count = content.movements.count
        guard count > 0 else {
            ready = true
            return
        }
        for i in 1...count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.45) {
                withAnimation(.easeOut(duration: 0.6)) { shown = i }
                Haptics.rigid()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(count) * 0.45) {
            withAnimation(.easeOut(duration: 0.4)) { ready = true }
            Haptics.soft()
        }
    }
}

// MARK: - Engagement : appui long

struct CommitScreen: View {
    let onNext: () -> Void

    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var done = false
    @State private var ticker: Timer?

    private let holdDuration = 2.2

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Une œuvre par jour.")
                .font(.figtree(34, .semibold)).foregroundStyle(Palette.ink)
            Text("Cinq minutes, chaque jour. Pas pour briller en société : pour toi.")
                .font(.aBody).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Spacer()

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
            .frame(width: 190, height: 190)
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
            .accessibilityLabel("Maintenir pour m'engager")
            .accessibilityAddTraits(.isButton)

            Text(done ? "C'est parti." : "Maintiens le doigt pour t'engager")
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
        // La vibration monte en intensité pendant l'appui.
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
