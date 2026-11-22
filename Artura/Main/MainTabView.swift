import SwiftUI

enum AppTab: Int, CaseIterable {
    case today, explore, review, games, profile

    /// Tab to open at launch, from the `-appTab` debug argument.
    static var debugInitial: AppTab? {
        switch AppDebug.string("appTab") {
        case "explore": return .explore
        case "review": return .review
        case "games": return .games
        case "profile": return .profile
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .explore: return "Explore"
        case .review: return "Review"
        case .games: return "Games"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .today: return "house.fill"
        case .explore: return "square.grid.2x2.fill"
        case .review: return "bookmark.fill"
        case .games: return "puzzlepiece.fill"
        case .profile: return "person.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var content: ContentStore
    @State private var tab: AppTab = AppTab.debugInitial ?? .today

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .today:
                    HomeFeedView(onExplore: { withAnimation(.snappy) { tab = .explore } },
                                 onReview: { withAnimation(.snappy) { tab = .review } })
                case .explore: ExploreView()
                case .review: ReviewView()
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
            .background(Palette.bg.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xEFE9E5)).frame(height: 1) }
        }
        .background(Palette.bg)
        .onAppear { content.activateCatalog() }
    }
}

// MARK: - Lesson → quiz flow, presented full screen

/// Opens a lesson. Lessons of the online catalog are downloaded the first time they are opened.
struct CourseFlow: View {
    @EnvironmentObject private var content: ContentStore
    @Environment(\.dismiss) private var dismiss
    let artwork: Artwork

    @State private var ready: Artwork?
    @State private var failed = false
    @State private var attempt = 0

    init(artwork: Artwork) {
        self.artwork = artwork
        _ready = State(initialValue: artwork.lesson.isEmpty ? nil : artwork)
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if let ready {
                CourseContent(artwork: ready)
                    .transition(.opacity)
            } else {
                waiting
            }
        }
        .task(id: attempt) {
            guard ready == nil else { return }
            failed = false
            let full = await content.withLesson(artwork)
            withAnimation(.gentle) {
                ready = full
                failed = full == nil
            }
            if full == nil { Haptics.soft() }
        }
    }

    private var waiting: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.card))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Close")
                Spacer()
            }
            Spacer()
            ArtImage(name: artwork.image)
                .frame(width: 180, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(artwork.title)
                .font(.aHeading).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if failed {
                Text("This lesson could not be loaded. Check your connection and try again.")
                    .font(.aSmall).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Haptics.press()
                    attempt += 1
                }
                .buttonStyle(.primary)
            } else {
                ProgressView().tint(Palette.blue)
                Text("Preparing your lesson").font(.aSmall).foregroundStyle(Palette.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

private struct CourseContent: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.dismiss) private var dismiss
    let artwork: Artwork

    @State private var phase = 0
    @State private var score = 0

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
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
                    title: score == artwork.quiz.count ? "Perfect score!" : "Lesson complete",
                    detail: "\(score) of \(artwork.quiz.count) correct",
                    celebrate: score == artwork.quiz.count,
                    shareArtwork: artwork,
                    onDone: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .onAppear { user.markOpened(artwork.id) }
    }
}

/// End screen, shared by the quiz and the games.
struct ResultView: View {
    let title: String
    let detail: String
    var celebrate: Bool = true
    /// Artwork to offer for sharing (end of a lesson).
    var shareArtwork: Artwork? = nil
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
                    .background(Circle().fill(celebrate ? Palette.mist : Palette.green))
                    .scaleEffect(pop ? 1 : 0.8)
                    .opacity(pop ? 1 : 0)
                Text(title).font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
                Text(detail).font(.aBody).foregroundStyle(Palette.muted).appearUp(0.3)
                Spacer()
                if let onReplay {
                    Button("Play again", action: onReplay).buttonStyle(.secondary)
                }
                if let shareArtwork {
                    ArtworkShareLink(artwork: shareArtwork) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold))
                            Text("Share this artwork")
                        }
                    }
                    .buttonStyle(.secondary)
                }
                Button("Done", action: onDone).buttonStyle(.primary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            if celebrate && pop { ConfettiView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .onAppear {
            withAnimation(.bouncy.delay(0.1)) { pop = true }
            if celebrate { Haptics.success() } else { Haptics.soft() }
        }
    }
}
