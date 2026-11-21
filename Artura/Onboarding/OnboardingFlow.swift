import SwiftUI

enum OnbStep: Int, CaseIterable {
    case welcome, quotes, promise, gender
    case flashTest, flashResult, help
    case phoneTime, phoneResult, statement, whatRemains, reviews
    case arts, goal, level, tastes, movements, map, rhythm
    case chooseCourse, lesson, quiz, streak
    case reminder, loading, plan, account
    case commit
    case trialIntro, trialTimeline, trialNotif, paywall

    /// Écrans qui affichent la barre de progression, dans l'ordre.
    static let numbered: [OnbStep] = [
        .gender, .flashTest, .flashResult, .phoneTime, .arts, .goal, .level,
        .tastes, .movements, .map, .rhythm, .chooseCourse, .lesson, .quiz, .streak,
        .reminder, .plan, .account
    ]

    static var numberedTotal: Int { numbered.count }

    /// Numéro affiché dans la barre de progression (nil = écran sans compteur).
    var number: Int? {
        guard let i = Self.numbered.firstIndex(of: self) else { return nil }
        return i + 1
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore

    @State private var step: OnbStep = .welcome
    @State private var forward = true

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            screen
                .id(step)
                .transition(.opacity)
        }
    }

    private var course: Artwork? {
        content.artwork(user.profile.firstCourse) ?? content.artwork("nuit") ?? content.artworks.first
    }

    private func go(_ target: OnbStep, forward isForward: Bool = true) {
        forward = isForward
        withAnimation(.easeInOut(duration: 0.2)) { step = target }
        // Petit « toc » quand le nouvel écran se pose.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Haptics.soft() }
    }

    private func next() {
        if let target = OnbStep(rawValue: step.rawValue + 1) {
            go(target)
        } else {
            finish()
        }
    }

    private func back() {
        guard let target = OnbStep(rawValue: step.rawValue - 1) else { return }
        Haptics.tap()
        go(target, forward: false)
    }

    private func finish() {
        Haptics.success()
        user.profile.onboarded = true
    }

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome: WelcomeScreen(onNext: next, onLogin: { go(.account) })
        case .quotes: QuotesScreen(onNext: next)
        case .promise: PromiseScreen(onNext: next)
        case .gender: GenderScreen(onBack: back, onNext: next)
        case .flashTest: FlashTestScreen(onBack: back, onNext: next)
        case .flashResult: FlashResultScreen(onBack: back, onNext: next)
        case .help: HelpScreen(onBack: back, onNext: next)
        case .phoneTime: PhoneTimeScreen(onBack: back, onNext: next)
        case .phoneResult: PhoneResultScreen(onNext: next)
        case .statement: StatementScreen(onNext: next)
        case .whatRemains: WhatRemainsScreen(onBack: back, onNext: next)
        case .reviews: ReviewsScreen(onBack: back, onNext: next)
        case .arts: ArtsScreen(onBack: back, onNext: next)
        case .goal: GoalScreen(onBack: back, onNext: next)
        case .level: LevelScreen(onBack: back, onNext: next)
        case .tastes: TastesScreen(onBack: back, onNext: next)
        case .movements: MovementsScreen(onBack: back, onNext: next)
        case .map: MapScreen(onBack: back, onNext: next)
        case .rhythm: RhythmScreen(onBack: back, onNext: next)
        case .chooseCourse: ChooseCourseScreen(onBack: back, onNext: next)
        case .lesson:
            if let course {
                LessonView(artwork: course, pill: "Ton premier cours", onBack: back, onFinish: next)
            }
        case .quiz:
            if let course {
                QuizView(artwork: course, onBack: back) { _ in
                    user.completeLesson(course.id)
                    next()
                }
            }
        case .streak: StreakScreen(onNext: next)
        case .reminder: ReminderScreen(onBack: back, onNext: next)
        case .loading: LoadingScreen(onNext: next)
        case .plan: PlanScreen(onBack: back, onNext: next)
        case .account: AccountScreen(onBack: back, onNext: next)
        case .commit: CommitScreen(onNext: next)
        case .trialIntro: TrialIntroScreen(onNext: next, onSkip: finish)
        case .trialTimeline: TrialTimelineScreen(onBack: back, onNext: next)
        case .trialNotif: TrialNotifScreen(onBack: back, onNext: next)
        case .paywall: PaywallScreen(onClose: finish)
        }
    }
}

// MARK: - Gabarits d'écran

/// Gabarit des écrans de question : barre de progression, titre, contenu, bouton.
struct OnbScaffold<Content: View>: View {
    var number: Int? = nil
    var onBack: (() -> Void)? = nil
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continuer"
    var ctaEnabled: Bool = true
    let onNext: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.pressable)
                    .padding(.leading, -12)
                }
                if let number {
                    ProgressTrack(value: Double(number) / Double(OnbStep.numberedTotal))
                    Text("\(number) / \(OnbStep.numberedTotal)")
                        .font(.figtree(14, .medium))
                        .foregroundStyle(Palette.muted)
                } else {
                    Spacer()
                }
            }
            .frame(height: 44)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.aBody)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .appearUp()

            content()

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Button(cta) { onNext() }
                    .buttonStyle(.primary)
                    .disabled(!ctaEnabled)
                    .opacity(ctaEnabled ? 1 : 0.4)
                    .animation(.snappy, value: ctaEnabled)
                if let secondaryTitle, let onSecondary {
                    TextLinkButton(title: secondaryTitle, action: onSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, secondaryTitle == nil ? 16 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}

/// Gabarit des écrans à grande illustration en haut.
struct HeroScaffold<Content: View>: View {
    let image: String
    var imageHeight: CGFloat = 410
    var number: Int? = nil
    var onBack: (() -> Void)? = nil
    var cta: String = "Continuer"
    let onNext: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var settle = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ArtImage(name: image)
                    .frame(height: imageHeight)
                    .clipShape(ArcHeaderShape())
                    .ignoresSafeArea(edges: .top)
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(.white))
                        }
                        .buttonStyle(.pressable)
                    }
                    Spacer()
                    if let number {
                        Text("\(number) / \(OnbStep.numberedTotal)")
                            .font(.figtree(14, .medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(.white))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 10) {
                content()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, -28)

            Spacer(minLength: 12)

            VStack(spacing: 4) {
                Button(cta) { onNext() }.buttonStyle(.primary)
                if let secondaryTitle, let onSecondary {
                    TextLinkButton(title: secondaryTitle, action: onSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, secondaryTitle == nil ? 16 : 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { settle = true }
        }
    }
}

// MARK: - Mise en page « pastilles qui passent à la ligne »

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
