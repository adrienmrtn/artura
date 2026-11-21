import SwiftUI

// MARK: 8 · Ton objectif

struct GoalScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    static let goals: [(String, String)] = [
        ("Enrichir ma culture générale", "Savoir de quoi on parle, enfin"),
        ("Me détendre quelques minutes", "Une pause loin des écrans qui crient"),
        ("Préparer une visite au musée", "Arriver devant les tableaux en les connaissant"),
        ("Par simple curiosité", "On verra bien où ça mène")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.goal.number, onBack: onBack, title: "Qu'est-ce qui t'amène ?",
                    subtitle: "Choisis ce qui te ressemble le plus.",
                    ctaEnabled: user.profile.goal != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(Self.goals.enumerated()), id: \.offset) { i, goal in
                    OptionRow(title: goal.0, subtitle: goal.1, selected: user.profile.goal == goal.0) {
                        user.profile.goal = goal.0
                    }
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: 9 · Ton niveau

struct LevelScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let levels: [(String, String, String)] = [
        ("Débutant", "Je reconnais la Joconde, et c'est déjà pas mal.", "art_joconde"),
        ("Amateur", "Je connais quelques artistes et courants.", "art_nuit"),
        ("Connaisseur", "Je distingue un Monet d'un Manet.", "art_impression")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.level.number, onBack: onBack, title: "Où en es-tu avec l'art ?",
                    subtitle: "Ça règle la difficulté des jeux. Tu pourras changer.",
                    ctaEnabled: user.profile.level != nil, onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, level in
                    let selected = user.profile.level == level.0
                    Button {
                        Haptics.selection()
                        user.profile.level = level.0
                    } label: {
                        HStack(spacing: 14) {
                            ArtImage(name: level.2)
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(level.0).font(.aCardTitle).foregroundStyle(Palette.ink)
                                Text(level.1).font(.aSmall).foregroundStyle(Palette.muted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if selected { CheckBadge().transition(.scale) }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.blueSelected : Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: 10 · Tes goûts

struct TastesScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let ids = ["vague", "nuit", "baiser", "tournesols", "joconde", "nympheas"]
    private var remaining: Int { 3 - user.profile.liked.count }

    var body: some View {
        OnbScaffold(number: OnbStep.tastes.number, onBack: onBack, title: "Choisis 3 œuvres qui t'attirent",
                    subtitle: "Sans réfléchir. On s'en sert pour tes recommandations.",
                    cta: remaining > 0 ? "Encore \(remaining)" : "Continuer",
                    ctaEnabled: remaining <= 0, onNext: onNext) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(ids.enumerated()), id: \.offset) { i, id in
                    if let art = content.artwork(id) {
                        let selected = user.profile.liked.contains(id)
                        Button {
                            if selected || remaining > 0 { Haptics.selection() } else { Haptics.warning() }
                            user.toggleLiked(id)
                        } label: {
                            ArtImage(name: art.image)
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
                                .overlay(alignment: .topTrailing) {
                                    if selected { CheckBadge().padding(8).transition(.scale) }
                                }
                                .scaleEffect(selected ? 0.96 : 1)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("\(art.title), \(art.artist)")
                        .animation(.bouncy, value: selected)
                        .appearUp(0.05 * Double(i))
                    }
                }
            }
        }
    }
}

// MARK: 11 · Tes courants

struct MovementsScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(number: OnbStep.movements.number, onBack: onBack, title: "Quels courants t'intriguent ?",
                    subtitle: "Autant que tu veux. On a coché ceux de tes œuvres préférées.",
                    cta: user.profile.movements.isEmpty ? "Continuer" : "Continuer · \(user.profile.movements.count)",
                    onNext: onNext, secondaryTitle: "Je ne sais pas encore", onSecondary: onNext) {
            FlowLayout(spacing: 10) {
                ForEach(content.movements) { movement in
                    let selected = user.profile.movements.contains(movement.id)
                    Button {
                        Haptics.selection()
                        user.toggleMovement(movement.id)
                    } label: {
                        HStack(spacing: 8) {
                            if selected {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            }
                            Text(movement.name).font(.figtree(15, .semibold))
                        }
                        .foregroundStyle(selected ? .white : Palette.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Capsule().fill(selected ? Palette.ink : Palette.card))
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                }
            }
            .appearUp(0.1)
        }
        .onAppear {
            guard user.profile.movements.isEmpty else { return }
            let suggested = user.profile.liked.compactMap { content.artwork($0)?.movementId }
            var unique: [String] = []
            for id in suggested where !unique.contains(id) { unique.append(id) }
            user.profile.movements = unique
        }
    }
}

// MARK: 12 · Ton rythme

struct RhythmScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let options: [(Int, String, String)] = [
        (2, "Tranquille", "Juste l'œuvre du jour"),
        (5, "Régulier", "L'œuvre et un jeu"),
        (10, "Passionné", "L'œuvre, un jeu et une leçon")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.rhythm.number, onBack: onBack, title: "Combien de temps par jour ?",
                    subtitle: "Mieux vaut peu et tous les jours.", onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    let selected = user.profile.minutes == option.0
                    Button {
                        Haptics.selection()
                        user.profile.minutes = option.0
                    } label: {
                        HStack(spacing: 16) {
                            Text("\(option.0) min")
                                .font(.figtree(26, .semibold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 84, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                if option.0 == 5 { TagPill(text: "Conseillé") }
                                Text(option.1).font(.bodyStrong).foregroundStyle(Palette.ink)
                                Text(option.2).font(.aSmall).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            if selected { CheckBadge().transition(.scale) }
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.blueSelected : Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: 13 · Choix du premier cours

struct ChooseCourseScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    private var choices: [Artwork] {
        let liked = user.profile.liked.compactMap { content.artwork($0) }
        return liked.isEmpty ? Array(content.artworks.prefix(3)) : liked
    }

    var body: some View {
        OnbScaffold(number: OnbStep.chooseCourse.number, onBack: onBack, title: "Choisis ton premier cours",
                    subtitle: "Parmi les œuvres qui t'ont \(user.agree("attiré", "attirée")) tout à l'heure.",
                    cta: "Commencer ce cours", ctaEnabled: user.profile.firstCourse != nil, onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(choices.enumerated()), id: \.element.id) { i, art in
                    let selected = user.profile.firstCourse == art.id
                    Button {
                        Haptics.selection()
                        user.profile.firstCourse = art.id
                    } label: {
                        HStack(spacing: 14) {
                            ArtImage(name: art.image).frame(width: 104, height: 116)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(art.title).font(.aCardTitle).foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                Text(art.meta).font(.aSmall).foregroundStyle(Palette.muted)
                                Text("Cours 3 min · quiz \(art.quiz.count) questions").font(.aCaption).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            if selected { CheckBadge().padding(.trailing, 14).transition(.scale) }
                        }
                        .background(selected ? Palette.blueSelected : Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
        .onAppear {
            if user.profile.firstCourse == nil || !choices.contains(where: { $0.id == user.profile.firstCourse }) {
                user.profile.firstCourse = choices.first?.id
            }
        }
    }
}

// MARK: 16 · Série lancée

struct StreakScreen: View {
    let onNext: () -> Void
    @State private var checked = false

    var body: some View {
        ZStack {
            HeroScaffold(image: "ill_serie", number: OnbStep.streak.number, onNext: onNext) {
                Text("Jour 1, c'est parti").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.1)
                Text("Un cours lu, un quiz terminé. Reviens demain pour faire grandir ta série.")
                    .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.2)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(day == 1 && checked ? Palette.yellow : .white)
                                if day == 1 && checked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                        .transition(.scale)
                                }
                            }
                            .frame(width: 36, height: 36)
                            Text("J\(day)")
                                .font(.figtree(12, day == 1 ? .bold : .regular))
                                .foregroundStyle(day == 1 ? Palette.ink : Palette.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                .padding(.top, 8)
                .appearUp(0.3)
            }
            if checked { ConfettiView() }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.bouncy) { checked = true }
                Haptics.success()
            }
        }
    }
}
