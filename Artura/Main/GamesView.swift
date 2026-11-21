import SwiftUI

enum GameKind: String, Identifiable, CaseIterable {
    case zoom, chronology, palette, trueFalse, training
    var id: String { rawValue }

    /// Les quatre jeux affichés dans la liste (l'entraînement a son propre bouton).
    static let listed: [GameKind] = [.zoom, .chronology, .palette, .trueFalse]

    var title: String {
        switch self {
        case .zoom: return "Zoom mystère"
        case .chronology: return "Chronologie"
        case .palette: return "Palette"
        case .trueFalse: return "Vrai ou faux"
        case .training: return "Entraînement"
        }
    }

    var subtitle: String {
        switch self {
        case .zoom: return "Devine l'œuvre à partir d'un détail · 1 min"
        case .chronology: return "Classe 4 œuvres par date · 2 min"
        case .palette: return "Retrouve les couleurs du tableau · 1 min"
        case .trueFalse: return "Anecdotes d'atelier · 1 min"
        case .training: return "Les quatre types de questions, mélangés"
        }
    }

    var image: String {
        switch self {
        case .zoom: return "ill_zoom"
        case .chronology: return "ill_chrono"
        case .palette: return "ill_palette"
        case .trueFalse: return "ill_vraifaux"
        case .training: return "ill_hero"
        }
    }
}

struct GamesView: View {
    @EnvironmentObject private var user: UserStore
    @State private var game: GameKind?

    /// Le défi du jour tourne entre les quatre jeux.
    private var daily: GameKind {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return GameKind.listed[day % GameKind.listed.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    ArtImage(name: "ill_musee", anchor: UnitPoint(x: 0.5, y: 0.1))
                        .frame(height: 160)
                        .clipShape(ArcHeaderShape())
                    Text("Jeux")
                        .font(.figtree(22, .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Capsule().fill(.white))
                        .padding(.leading, 16)
                        .padding(.top, 60)
                }

                VStack(alignment: .leading, spacing: 12) {
                    weekCard
                    VStack(spacing: 6) {
                        TrainingButton { game = .training }
                    }
                    .padding(.vertical, 4)
                    Text("Ou choisis un jeu").font(.aHeading).foregroundStyle(Palette.ink)
                    ForEach(Array(GameKind.listed.enumerated()), id: \.element.id) { i, kind in
                        gameRow(kind).appearUp(0.06 * Double(i + 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, -20)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(item: $game) { kind in
            GameHost(kind: kind)
        }
    }

    private var weekCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(user.streak == 0 ? "Lance ta série" : "Série de \(user.streak) jour\(user.streak > 1 ? "s" : "")")
                    .font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text(user.playedToday ? "C'est fait pour aujourd'hui" : "Joue aujourd'hui pour la garder")
                    .font(.aCaption).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 6) {
                ForEach(user.week) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(day.played ? Palette.yellow : .white)
                            if day.played {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(day.isToday && !day.played ? Palette.blue : .clear, lineWidth: 2))
                        Text(day.label)
                            .font(.figtree(12, day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? Palette.ink : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
    }

    private func gameRow(_ kind: GameKind) -> some View {
        Button {
            game = kind
        } label: {
            HStack(spacing: 14) {
                ArtImage(name: kind.image).frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 3) {
                    if kind == daily { TagPill(text: "Défi du jour") }
                    Text(kind.title).font(.aCardTitle).foregroundStyle(Palette.ink)
                    Text(kind.subtitle).font(.aCaption).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                    .padding(.trailing, 14)
            }
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.pressable)
    }
}

/// Enveloppe commune aux jeux : barre du haut, partie, écran de fin.
struct GameHost: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.dismiss) private var dismiss
    let kind: GameKind

    @State private var result: (score: Int, total: Int)?
    private var trainingDone: Bool { kind == .training && user.trainingFinished }
    @State private var round = 0

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if let result {
                ResultView(
                    title: trainingDone ? "Tu as fini ton entraînement du jour !"
                        : (result.score == result.total ? "Sans faute !" : (result.score * 2 >= result.total ? "Bien joué" : "On retente ?")),
                    detail: trainingDone ? "\(result.score) sur \(result.total) · reviens demain pour 30 nouvelles questions"
                        : "\(result.score) sur \(result.total)",
                    celebrate: trainingDone || result.score * 2 >= result.total,
                    onReplay: kind == .training ? nil : {
                        Haptics.tap()
                        withAnimation(.gentle) {
                            self.result = nil
                            round += 1
                        }
                    },
                    onDone: { dismiss() }
                )
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Palette.card))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Quitter le jeu")
                        Spacer()
                        Text(kind.title).font(.figtree(17, .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Group {
                        switch kind {
                        case .zoom: ZoomGame(onFinish: finish)
                        case .chronology: ChronologyGame(onFinish: finish)
                        case .palette: PaletteGame(onFinish: finish)
                        case .trueFalse: TrueFalseGame(onFinish: finish)
                        case .training: TrainingGame(onFinish: finish)
                        }
                    }
                    .id(round)
                }
                .transition(.opacity)
            }
        }
        .onAppear { Haptics.soft() }
    }

    private func finish(_ score: Int, _ total: Int) {
        Haptics.press()
        user.recordGame(won: score * 2 >= total)
        withAnimation(.gentle) { result = (score, total) }
    }
}

/// Bouton « S'entraîner » avec le compteur du jour ; grisé une fois les 30 questions faites.
struct TrainingButton: View {
    @EnvironmentObject private var user: UserStore
    let action: () -> Void

    private var caption: String {
        let goal = UserStore.trainingDailyGoal
        if user.trainingFinished { return "Tu as fini ton entraînement du jour. Reviens demain !" }
        if user.trainingDoneToday == 0 { return "\(goal) questions par jour, les quatre jeux mélangés." }
        return "\(user.trainingDoneToday) sur \(goal) aujourd'hui · encore \(user.trainingRemaining)"
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(user.trainingFinished ? "Entraînement terminé" : (user.trainingDoneToday == 0 ? "S'entraîner" : "Reprendre l'entraînement")) {
                action()
            }
            .buttonStyle(.primary)
            .disabled(user.trainingFinished)
            .opacity(user.trainingFinished ? 0.4 : 1)
            ProgressTrack(value: Double(user.trainingDoneToday) / Double(UserStore.trainingDailyGoal))
            Text(caption)
                .font(.aCaption).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
    }
}
