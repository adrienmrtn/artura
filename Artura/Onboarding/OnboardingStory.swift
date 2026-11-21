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

// MARK: - Citations : un seul écran, elles apparaissent une à une

struct Quote: Identifiable {
    let image: String
    let text: String
    let author: String
    let role: String
    var id: String { author }

    // Citations à faire vérifier (source et traduction) avant la mise en ligne.
    static let all: [Quote] = [
        Quote(image: "portrait_klee", text: "L'art ne reproduit pas le visible, il rend visible.", author: "Paul Klee", role: "Peintre"),
        Quote(image: "portrait_nietzsche", text: "Nous avons l'art pour ne pas mourir de la vérité.", author: "Friedrich Nietzsche", role: "Philosophe"),
        Quote(image: "portrait_proust", text: "Par l'art seulement, nous pouvons sortir de nous.", author: "Marcel Proust", role: "Écrivain"),
        Quote(image: "portrait_malraux", text: "L'art est un anti-destin.", author: "André Malraux", role: "Écrivain"),
        Quote(image: "portrait_wilde", text: "La vie imite l'art bien plus que l'art n'imite la vie.", author: "Oscar Wilde", role: "Écrivain")
    ]
}

struct QuotesScreen: View {
    let onNext: () -> Void
    @State private var shown = 0

    private let quotes = Quote.all
    private let pace = 1.7

    var body: some View {
        SlowScreen(duration: 0.8 + Double(quotes.count) * pace + 0.6, dark: true, onNext: onNext) {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                    HStack(alignment: .top, spacing: 14) {
                        ArtImage(name: quote.image, anchor: .top)
                            .saturation(0)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("« \(quote.text) »")
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
        }
        .onAppear {
            for i in 1...quotes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i - 1) * pace) {
                    withAnimation(.easeOut(duration: 1.1)) { shown = i }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: - Test éclair : 5 chefs-d'œuvre empilés, oui ou non

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
                Text("Sans tricher. Glisse la carte, ou réponds avec les boutons.")
                    .font(.aBody).foregroundStyle(Palette.muted)
            }

            // Pile de cartes : la suivante dépasse derrière celle du dessus.
            ZStack {
                ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { i, art in
                    if i >= index && i <= index + 2 {
                        let depth = i - index
                        card(art, top: depth == 0)
                            .scaleEffect(1 - CGFloat(depth) * 0.05)
                            .offset(y: CGFloat(depth) * 16)
                            .rotationEffect(.degrees(depth == 0 ? Double(drag.width) / 22 : (depth == 1 ? 2.5 : -2.5)))
                            .offset(x: depth == 0 ? drag.width : 0, y: depth == 0 ? drag.height * 0.15 : 0)
                            .zIndex(Double(cards.count - i))
                            .allowsHitTesting(depth == 0)
                    }
                }
            }
            .padding(.bottom, 34)
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button("Non") { answer(false) }.buttonStyle(.secondary)
                Button("Oui") { answer(true) }.buttonStyle(.primary)
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
                if top { stamp("Oui", Palette.green).opacity(stampOpacity(true)).padding(16) }
            }
            .overlay(alignment: .topTrailing) {
                if top { stamp("Non", Palette.ink).opacity(stampOpacity(false)).padding(16) }
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
        // La carte sort de l'écran du côté de la réponse, puis la suivante monte.
        withAnimation(.easeIn(duration: 0.18)) {
            drag = CGSize(width: knows ? 500 : -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if index >= cards.count - 1 {
                user.profile.flashKnown = known
                onNext()
            } else {
                drag = .zero
                withAnimation(.easeOut(duration: 0.2)) { index += 1 }
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
    @State private var fanned = false
    @State private var statShown = false
    @State private var ready = false

    private var cards: [Artwork] { FlashTestScreen.ids.compactMap { content.artwork($0) } }
    private var total: Int { cards.count }
    private var score: Int { user.profile.flashKnown.count }

    private var verdict: String {
        if score == total { return "Tu les reconnais toutes. Mais sais-tu ce qu'elles racontent ?" }
        if score == 0 { return "Aucune pour l'instant. C'est exactement pour ça qu'on est là." }
        return "Les autres t'échappent encore. Plus pour longtemps."
    }

    var body: some View {
        VStack(spacing: 0) {
            // Les cinq œuvres en éventail : celles reconnues en couleur, les autres voilées.
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
                .accessibilityLabel("Retour")
                .padding(.leading, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(count)")
                        .font(.figtree(72, .semibold))
                        .foregroundStyle(Palette.blue)
                        .contentTransition(.numericText())
                    Text("sur \(total)").font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                }
                Text(score > 1 ? "œuvres reconnues" : "œuvre reconnue")
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

            // Statistique à sourcer précisément avant la mise en ligne
            // (étude sur le temps passé devant les œuvres, Art Institute of Chicago, 2017).
            HStack(spacing: 0) {
                ArtImage(name: "ill_regard", anchor: UnitPoint(x: 0.5, y: 0.6))
                    .frame(width: 118)
                VStack(alignment: .leading, spacing: 4) {
                    Text("28 secondes").font(.figtree(26, .semibold)).foregroundStyle(.white)
                    Text("C'est le temps moyen passé devant une œuvre au musée. Reconnaître n'est pas encore regarder.")
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

            Button("Continuer") { onNext() }
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

// MARK: - Le temps passé sur ton téléphone (la question)

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var hours: Double = 4
    @State private var glow = false

    private var hoursLabel: String {
        let whole = Int(hours)
        return hours == Double(whole) ? "\(whole) h" : "\(whole) h 30"
    }

    var body: some View {
        OnbScaffold(number: OnbStep.phoneTime.number, onBack: onBack,
                    title: "Combien de temps par jour sur ton téléphone ?",
                    subtitle: "Regarde dans Réglages › Temps d'écran si tu hésites.",
                    onNext: save) {
            ArtImage(name: "ill_phone", zoom: glow ? 1.08 : 1, anchor: UnitPoint(x: 0.5, y: 0.45))
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 0) {
                Text(hoursLabel)
                    .font(.figtree(52, .semibold)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("par jour").font(.aBody).foregroundStyle(Palette.muted)
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

// MARK: - Ce que ça représente sur une année (écran lent)

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
        return hours == Double(whole) ? "\(whole) h" : "\(whole) h 30"
    }

    private var monthsLine: String {
        let months = Double(target) / 30.4
        if months < 1.25 { return "Plus d'un mois entier, chaque année." }
        return "Près de \(Int(months.rounded())) mois entiers, chaque année."
    }

    var body: some View {
        SlowScreen(duration: 6.2, dark: true, onNext: onNext) {
            VStack(spacing: 14) {
                Spacer()
                Text("\(hoursLabel) par jour, c'est")
                    .font(.figtree(22, .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .opacity(stage >= 1 ? 1 : 0)
                Text("\(days)")
                    .font(.figtree(120, .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .opacity(stage >= 2 ? 1 : 0)
                Text("jours par an")
                    .font(.figtree(28, .semibold))
                    .foregroundStyle(.white)
                    .opacity(stage >= 2 ? 1 : 0)
                Text(monthsLine)
                    .font(.aBody)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .opacity(stage >= 3 ? 1 : 0)
                    .padding(.top, 6)
                Spacer()
                Text("Artura t'en demande cinq minutes.")
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
            // Le compteur monte lentement jusqu'au total, avec un tic à chaque pas.
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
