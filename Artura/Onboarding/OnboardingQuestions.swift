import SwiftUI

// MARK: 8 · Your goal

struct GoalScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    /// (stored value, displayed label, subtitle). The stored value stays as is so saved profiles keep working.
    static let goals: [(String, String, String)] = [
        ("Enrichir ma culture générale", "Build my general knowledge", "Finally know what everyone's talking about"),
        ("Me détendre quelques minutes", "Unwind for a few minutes", "A break from all the noisy screens"),
        ("Préparer une visite au musée", "Get ready for a museum visit", "Walk in already knowing the paintings"),
        ("Par simple curiosité", "Just curious", "Let's see where it leads")
    ]

    /// Displayed label for a stored goal value.
    static func label(for value: String) -> String {
        goals.first(where: { $0.0 == value })?.1 ?? value
    }

    var body: some View {
        OnbScaffold(number: OnbStep.goal.number, onBack: onBack, title: "What brings you here?",
                    subtitle: "Pick the one that sounds most like you.",
                    ctaEnabled: user.profile.goal != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(Self.goals.enumerated()), id: \.offset) { i, goal in
                    OptionRow(title: goal.1, subtitle: goal.2, selected: user.profile.goal == goal.0) {
                        user.profile.goal = goal.0
                    }
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: 9 · Your level

struct LevelScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let levels: [(String, String, String)] = [
        ("Beginner", "I can spot the Mona Lisa, and that's a start.", "art_joconde"),
        ("Enthusiast", "I know a few artists and movements.", "art_nuit"),
        ("Connoisseur", "I can tell a Monet from a Manet.", "art_impression")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.level.number, onBack: onBack, title: "How well do you know art?",
                    subtitle: "This sets how hard the games are. You can change it later.",
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

// MARK: 10 · Your tastes

struct TastesScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let ids = ["vague", "nuit", "baiser", "tournesols", "joconde", "nympheas"]
    private var remaining: Int { 3 - user.profile.liked.count }

    var body: some View {
        OnbScaffold(number: OnbStep.tastes.number, onBack: onBack, title: "Pick 3 artworks you're drawn to",
                    subtitle: "Don't overthink it. We'll use them for your recommendations.",
                    cta: remaining > 0 ? "\(remaining) more to go" : "Continue",
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

// MARK: 11 · Your movements

struct MovementsScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(number: OnbStep.movements.number, onBack: onBack, title: "Which movements intrigue you?",
                    subtitle: "As many as you like.",
                    cta: user.profile.movements.isEmpty ? "Continue" : "Continue · \(user.profile.movements.count)",
                    onNext: onNext, secondaryTitle: "Not sure yet", onSecondary: onNext) {
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
    }
}

// MARK: 12 · Your pace

struct RhythmScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let options: [(Int, String, String)] = [
        (2, "Easygoing", "Just the artwork of the day"),
        (5, "Steady", "The artwork and a game"),
        (10, "Devoted", "The artwork, a game, and a lesson")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.rhythm.number, onBack: onBack, title: "How much time each day?",
                    subtitle: "A little every day works best.", onNext: onNext) {
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
                                if option.0 == 5 { TagPill(text: "Recommended") }
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

// MARK: 13 · Choosing the first lesson

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
        OnbScaffold(number: OnbStep.chooseCourse.number, onBack: onBack, title: "Choose your first lesson",
                    subtitle: "From the artworks that caught your eye earlier.",
                    cta: "Start this lesson", ctaEnabled: user.profile.firstCourse != nil, onNext: onNext) {
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
                                Text("3-min lesson · \(art.quiz.count)-question quiz").font(.aCaption).foregroundStyle(Palette.muted)
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

// MARK: 16 · Streak started

struct StreakScreen: View {
    let onNext: () -> Void
    @State private var checked = false

    var body: some View {
        ZStack {
            HeroScaffold(image: "ill_serie", number: OnbStep.streak.number, onNext: onNext) {
                Text("Day 1, here we go").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.1)
                Text("One lesson read, one quiz done. Come back tomorrow to grow your streak.")
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
                            Text("Day \(day)")
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
