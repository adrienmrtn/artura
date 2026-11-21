import SwiftUI

enum AppTab: Int, CaseIterable {
    case today, explore, games, profile

    var title: String {
        switch self {
        case .today: return "Aujourd'hui"
        case .explore: return "Explorer"
        case .games: return "Jeux"
        case .profile: return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .today: return "house.fill"
        case .explore: return "square.grid.2x2.fill"
        case .games: return "puzzlepiece.fill"
        case .profile: return "person.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .today: TodayView(onExplore: { withAnimation(.snappy) { tab = .explore } })
                case .explore: ExploreView()
                case .games: GamesView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(tab)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.rawValue) { item in
                    Button {
                        guard tab != item else { return }
                        Haptics.selection()
                        withAnimation(.snappy) { tab = item }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20))
                                .scaleEffect(tab == item ? 1.06 : 1)
                            Text(item.title).font(.figtree(11, .medium))
                        }
                        .foregroundStyle(tab == item ? Palette.ink : Color(hex: 0x6B6661))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xEFE9E5)).frame(height: 1) }
        }
        .background(Color.white)
    }
}

// MARK: - Parcours cours → quiz, présenté en plein écran

struct CourseFlow: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.dismiss) private var dismiss
    let artwork: Artwork

    @State private var phase = 0
    @State private var score = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            switch phase {
            case 0:
                LessonView(artwork: artwork, onBack: { dismiss() }) {
                    Haptics.soft()
                    withAnimation(.gentle) { phase = 1 }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            case 1:
                QuizView(artwork: artwork, onBack: { withAnimation(.gentle) { phase = 0 } }) { result in
                    score = result
                    user.completeLesson(artwork.id)
                    withAnimation(.gentle) { phase = 2 }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            default:
                ResultView(
                    title: score == artwork.quiz.count ? "Sans faute !" : "Cours terminé",
                    detail: "\(score) bonne\(score > 1 ? "s" : "") réponse\(score > 1 ? "s" : "") sur \(artwork.quiz.count)",
                    celebrate: score == artwork.quiz.count,
                    onDone: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .onAppear { user.markOpened(artwork.id) }
    }
}

/// Écran de fin, commun au quiz et aux jeux.
struct ResultView: View {
    let title: String
    let detail: String
    var celebrate: Bool = true
    var onReplay: (() -> Void)? = nil
    let onDone: () -> Void
    @State private var pop = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: celebrate ? "star.fill" : "checkmark")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(celebrate ? Palette.yellow : .white)
                    .frame(width: 132, height: 132)
                    .background(Circle().fill(celebrate ? Palette.blueSoft : Palette.green))
                    .scaleEffect(pop ? 1 : 0.8)
                    .opacity(pop ? 1 : 0)
                Text(title).font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
                Text(detail).font(.aBody).foregroundStyle(Palette.muted).appearUp(0.3)
                Spacer()
                if let onReplay {
                    Button("Rejouer", action: onReplay).buttonStyle(.secondary)
                }
                Button("Terminer", action: onDone).buttonStyle(.primary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            if celebrate && pop { ConfettiView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            withAnimation(.bouncy.delay(0.1)) { pop = true }
            if celebrate { Haptics.success() } else { Haptics.soft() }
        }
    }
}
