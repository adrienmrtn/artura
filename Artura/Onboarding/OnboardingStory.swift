import SwiftUI

// MARK: - Test : de combien de ces tableaux connais-tu le nom ?

/// Carte du test d'entrée. Les deux dernières sont volontairement très difficiles.
struct FlashCard: Identifiable {
    let id: String
    let title: String
    let artist: String
    var hard = false
    var image: String { "art_\(id)" }

    static let all: [FlashCard] = [
        FlashCard(id: "joconde", title: "La Joconde", artist: "Léonard de Vinci"),
        FlashCard(id: "nuit", title: "La Nuit étoilée", artist: "Vincent van Gogh"),
        FlashCard(id: "vague", title: "La Grande Vague de Kanagawa", artist: "Katsushika Hokusai"),
        FlashCard(id: "perle", title: "La Jeune Fille à la perle", artist: "Johannes Vermeer"),
        FlashCard(id: "baiser", title: "Le Baiser", artist: "Gustav Klimt"),
        FlashCard(id: "raboteurs", title: "Les Raboteurs de parquet", artist: "Gustave Caillebotte", hard: true),
        FlashCard(id: "moine", title: "Le Moine au bord de la mer", artist: "Caspar David Friedrich", hard: true)
    ]
}

struct FlashTestScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var armed = false
    @State private var known: [String] = []
    /// Cartes déjà notées et le côté par lequel elles sont sorties.
    @State private var gone: [String: CGFloat] = [:]

    private let cards = FlashCard.all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TagPill(text: "Tableau \(min(index + 1, cards.count)) sur \(cards.count)")
                Text("De combien de ces tableaux connais-tu le nom ?")
                    .font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sans tricher. Glisse la carte, ou réponds avec les boutons.")
                    .font(.aBody).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enter()

            // Pile de cartes : la suivante dépasse derrière celle du dessus.
            ZStack {
                ForEach(Array(cards.enumerated()).reversed(), id: \.element.id) { i, item in
                    if i <= index + 2 {
                        // Une carte notée garde sa place hors écran : elle ne revient jamais au centre.
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
                Button("Je ne sais pas") { answer(false) }.buttonStyle(.secondary)
                Button("Je connais") { answer(true) }.buttonStyle(.primary)
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
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.card, lineWidth: 5))
            .shadow(color: Palette.navyDark.opacity(0.16), radius: 12, y: 6)
            .overlay(alignment: .bottomLeading) {
                if item.hard { TagPill(text: "Niveau expert").padding(16) }
            }
            .overlay(alignment: .topLeading) {
                if top { stamp("Je connais", Palette.green).opacity(stampOpacity(true)).padding(16) }
            }
            .overlay(alignment: .topTrailing) {
                if top { stamp("Je ne sais pas", Palette.ink).opacity(stampOpacity(false)).padding(16) }
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
        // La carte sort du côté de la réponse pendant que la suivante monte, dans la même animation.
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

// MARK: - Résultat du test : « Bravo, Max ! »

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
        if score == 0 { return firstName.map { "Merci pour ta franchise, \($0)." } ?? "Merci pour ta franchise." }
        return firstName.map { "Bravo, \($0) !" } ?? "Bravo !"
    }

    private var verdict: String {
        if score == total { return "Tu les connais tous, même les deux plus pointus. Mais sais-tu ce qu'ils racontent ?" }
        if score == 0 { return "Aucun pour l'instant. C'est exactement pour ça qu'on est là." }
        return "Les autres t'échappent encore. Plus pour longtemps."
    }

    var body: some View {
        ZStack {
            OnbScaffold(title: headline, spoken: true, onNext: onNext) {
                // Les sept tableaux en éventail : ceux nommés en couleur, les autres voilés.
                HStack(spacing: -36) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, item in
                        let known = user.profile.flashKnown.contains(item.id)
                        let spread = CGFloat(i) - CGFloat(cards.count - 1) / 2
                        ArtImage(name: item.image)
                            .saturation(known ? 1 : 0)
                            .opacity(known ? 1 : 0.55)
                            .frame(width: 78, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.card, lineWidth: 3))
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
                            .shadow(color: Palette.navyDark.opacity(0.16), radius: 8, y: 4)
                            .zIndex(known ? 2 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .enter(2)

                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(count)")
                            .font(.serif(72, .bold))
                            .foregroundStyle(Palette.navy)
                            .contentTransition(.numericText())
                        Text("sur \(total)").font(.serif(28)).foregroundStyle(Palette.ink)
                    }
                    Text(score > 1 ? "tableaux nommés" : "tableau nommé")
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
        // Le compteur monte d'un cran à la fois, avec un tic.
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

// MARK: - Ce que le temps d'écran représente, et ce qu'il peut devenir

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
        if months < 1.25 { return "Plus d'un mois entier, chaque année." }
        return "Près de \(Int(months.rounded())) mois entiers, chaque année."
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text("\(formatHours(hours)) par jour sur ton téléphone, c'est")
                    .font(.figtree(17, .medium))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(stage >= 1 ? 1 : 0)
                Text("\(days)")
                    .font(.serif(112, .bold))
                    .foregroundStyle(Palette.orange)
                    .contentTransition(.numericText())
                    .opacity(stage >= 2 ? 1 : 0)
                Text("jours par an")
                    .font(.serif(28))
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

            // Le retournement : ce temps peut servir à autre chose.
            VStack(spacing: 10) {
                Text("Avec Artura, ce temps peut devenir connaissance.")
                    .font(.serif(26))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Plutôt que de scroller sans fin, nourris ton esprit des plus grandes œuvres de l'humanité. Cinq minutes suffisent.")
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

            Button("Continuer") { onNext() }
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
            // Le compteur monte jusqu'au total, avec un tic à chaque pas.
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

// MARK: - Dans un an : près de 400 tableaux

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
            Text("Avec Artura, dans un an, tu connaîtras près de")
                .font(.serif(22, .medium)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .enter()

            Text("\(count)")
                .font(.serif(104, .bold))
                .foregroundStyle(Palette.navy)
                .contentTransition(.numericText())
                .padding(.top, 2)
            Text("tableaux")
                .font(.serif(28)).foregroundStyle(Palette.ink)

            // Un carré par tableau : la grille se remplit au rythme du compteur.
            Canvas { context, size in
                let gap: CGFloat = 3
                let cell = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
                for i in 0..<(columns * rows) {
                    let x = CGFloat(i % columns) * (cell + gap)
                    let y = CGFloat(i / columns) * (cell + gap)
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    let path = Path(roundedRect: rect, cornerRadius: 2.5)
                    // Quelques carrés dorés pour le relief, comme des cadres.
                    let filled = i < count
                    let color = !filled ? Palette.line : (i % 7 == 3 ? Palette.yellow : Palette.navy)
                    context.fill(path, with: .color(color))
                }
            }
            .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
            .padding(.top, 22)
            .enter(2)
            .accessibilityHidden(true)

            Text("Et pas seulement leur nom : tu les connaîtras en détail.")
                .font(.figtree(17)).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .opacity(detailShown ? 1 : 0)
                .offset(y: detailShown ? 0 : 12)

            Spacer(minLength: 16)

            Button("Continuer") { onNext() }
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
                // Départ rapide, arrivée en douceur.
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

// MARK: - Quelques minutes par jour, ça change tout (courbe)

/// Courbe de progression : part du bas à gauche et monte jusqu'à `lift` (part de la hauteur) à droite.
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
                    // Lignes de repère
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
                        .stroke(Palette.navy, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(inset)

                    dot(Palette.navy)
                        .position(x: rect.minX, y: GrowthCurve.y(GrowthCurve.startLift, in: rect))
                    dot(Palette.yellow)
                        .scaleEffect(ended ? 1 : 0.3).opacity(ended ? 1 : 0)
                        .position(x: rect.maxX, y: GrowthCurve.y(withoutLift, in: rect))
                    dot(Palette.navy)
                        .scaleEffect(ended ? 1 : 0.3).opacity(ended ? 1 : 0)
                        .position(x: rect.maxX, y: GrowthCurve.y(withLift, in: rect))
                }
            }
            .frame(height: 150)

            HStack {
                Text("Aujourd'hui").font(.aSmall).foregroundStyle(Palette.muted)
                Spacer()
                Text("Dans 1 an").font(.figtree(14, .semibold)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, inset)

            HStack(spacing: 18) {
                legend("Avec Artura", color: Palette.navy, dashed: false)
                legend("Sans routine", color: Palette.yellow, dashed: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Courbe : avec Artura, tes connaissances montent nettement en un an ; sans routine, elles restent presque au même niveau.")
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
            .fill(Palette.card)
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

    private let gains = ["ton regard", "ta culture générale", "tes sujets de conversation"]

    var body: some View {
        OnbScaffold(title: "Quelques minutes par jour, ça change tout.", spoken: true, onNext: onNext) {
            GrowthChart()
                .enter(2)

            VStack(alignment: .leading, spacing: 0) {
                Text("Avec Artura, tu développes")
                    .font(.serif(19)).foregroundStyle(Palette.ink)
                    .padding(.bottom, 6)
                ForEach(Array(gains.enumerated()), id: \.offset) { i, gain in
                    HStack {
                        Text(gain).font(.aBody).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.orange)
                    }
                    .frame(height: 34)
                    .enter(Double(i) * 2 + 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
            .enter(4)
        }
    }
}

// MARK: - Série : « Max, ton apprentissage commence aujourd'hui »

struct StreakScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var lit = false
    @State private var checked = false

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "\(name), ton apprentissage commence aujourd'hui."
        }
        return "Ton apprentissage commence aujourd'hui."
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ArtImage(name: "ill_serie", zoom: lit ? 1.06 : 1, anchor: UnitPoint(x: 0.5, y: 0.6))
                    .frame(minHeight: 150, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .bottom) {
                        // La flamme du premier jour, à cheval sur le bas de l'image.
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.orange)
                            Text("Jour 1")
                                .font(.serif(22, .bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(Capsule().fill(Palette.card).shadow(color: Palette.navyDark.opacity(0.14), radius: 12, y: 6))
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
                    Text("Reviens demain pour faire grandir ta série.")
                        .font(.figtree(17))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(4.5)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 48)

                // La semaine : le premier jour se coche.
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
                            Text("J\(day)")
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

                Button("Continuer") { onNext() }
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
