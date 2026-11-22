import SwiftUI

enum OnbStep: Int, CaseIterable {
    // 1 · The promise
    case welcome, hello, daily, pocketMuseum, photo, quotes
    // 2 · Getting to know each other
    case questionsIntro, name, gender, motivation, arts, recognize, knowledge, museum
    // 3 · The test
    case testIntro, flashTest, flashResult
    // 4 · The demo
    case understand, lesson, afterLesson
    // 5 · The turning point: that time can become knowledge
    case phoneTime, phoneResult, projection, graph
    // 6 · The commitment
    case streak, reminder, widget, loading, plan, socialProof, account
    // 7 · The gift: the free trial
    case gift, noCommitment, trial

    /// Screens that show the shared bar (back + progress).
    /// The others are full-page or have their own header.
    var showsBar: Bool {
        switch self {
        case .welcome, .lesson, .loading, .account, .gift, .noCommitment, .trial: return false
        default: return true
        }
    }

    /// Progress through the onboarding, from 0 to 1 (the bar is full at the account screen).
    var progress: Double {
        min(1, Double(rawValue) / Double(OnbStep.account.rawValue))
    }

    /// Screen shown when going back (nil = no way back).
    var previous: OnbStep? {
        switch self {
        case .welcome, .gift, .noCommitment, .trial: return nil
        // The loading screen replays by itself: skip it when going back.
        case .plan: return .widget
        default: return OnbStep(rawValue: rawValue - 1)
        }
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var pro: ProStore

    @State private var step: OnbStep = OnboardingDebug.startStep ?? .welcome
    /// Direction of the last move: it decides which side the screens glide from.
    @State private var forward = true
    /// True during a screen change: a double tap doesn't skip a step.
    @State private var moving = false
    /// True if the account screen was reached through "I already have an account".
    @State private var loginShortcut = false

    var body: some View {
        VStack(spacing: 0) {
            if step.showsBar {
                bar.transition(.opacity)
            }
            screen
                .id(step)
                .transition(.onbGlide(forward: forward))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
    }

    /// Shared bar: it stays in place from one screen to the next, only the progress moves.
    private var bar: some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)
            .padding(.leading, -12)
            .accessibilityLabel("Back")
            ProgressTrack(value: step.progress)
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var course: Artwork? {
        content.artwork(user.profile.firstCourse) ?? content.artwork("nuit") ?? content.artworks.first
    }

    /// Trial offer shown at the end. Until the StoreKit product is loaded, sample prices keep the flow visible.
    private var offer: TrialOffer? {
        TrialOffer(pro.yearly) ?? TrialOffer(previewDays: 3)
    }

    /// Gift offer, shown once when the visitor is about to leave: a longer trial and a lower yearly price.
    private var extendedOffer: TrialOffer? {
        TrialOffer(pro.yearlyExtended) ?? TrialOffer(previewDays: 7, gift: true)
    }

    // MARK: Navigation

    private func go(_ target: OnbStep) {
        guard !moving, target != step else { return }
        moving = true
        let isForward = target.rawValue > step.rawValue
        if isForward != forward {
            // The direction changes: let the current screen learn it before sending it out.
            forward = isForward
            DispatchQueue.main.async { move(to: target) }
        } else {
            move(to: target)
        }
    }

    private func move(to target: OnbStep) {
        withAnimation(.glide) { step = target }
        // A small tap when the new screen settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Haptics.soft() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { moving = false }
    }

    private func next() {
        // After the account comes the gift, if there is a trial offer to present.
        if step == .account, offer == nil || pro.isPro {
            finish()
        } else if let target = OnbStep(rawValue: step.rawValue + 1) {
            go(target)
        } else {
            finish()
        }
    }

    private func back() {
        guard let target = step.previous else { return }
        Haptics.tap()
        if step == .account && loginShortcut {
            loginShortcut = false
            go(.welcome)
        } else {
            go(target)
        }
    }

    private func finish() {
        Haptics.success()
        user.profile.onboarded = true
    }

    // MARK: Screens

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome:
            WelcomeScreen(onNext: next, onLogin: {
                loginShortcut = true
                go(.account)
            })
        case .hello: HelloScreen(onNext: next)
        case .daily: DailyScreen(onNext: next)
        case .pocketMuseum: PocketMuseumScreen(onNext: next)
        case .photo: PhotoScreen(onNext: next)
        case .quotes: QuotesScreen(onNext: next)
        case .questionsIntro: QuestionsIntroScreen(onNext: next)
        case .name: NameScreen(onNext: next)
        case .gender: GenderScreen(onNext: next)
        case .motivation: MotivationScreen(onNext: next)
        case .arts: ArtsScreen(onNext: next)
        case .recognize: RecognizeScreen(onNext: next)
        case .knowledge: KnowledgeScreen(onNext: next)
        case .museum: MuseumScreen(onNext: next)
        case .testIntro: TestIntroScreen(onNext: next)
        case .flashTest: FlashTestScreen(onNext: next)
        case .flashResult: FlashResultScreen(onNext: next)
        case .understand: UnderstandScreen(artwork: course, onNext: next)
        case .lesson:
            if let course {
                // An excerpt of the lesson: the beginning and a single interaction on the painting.
                LessonView(artwork: course, pill: "Your first guided tour",
                           blocks: course.previewLesson, finishTitle: "Finish the tour",
                           onSkip: next, onBack: back) {
                    user.profile.firstCourse = course.id
                    user.markOpened(course.id)
                    user.markPlayedToday()
                    next()
                }
            }
        case .afterLesson: AfterLessonScreen(onNext: next)
        case .phoneTime: PhoneTimeScreen(onNext: next)
        case .phoneResult: PhoneResultScreen(onNext: next)
        case .projection: ProjectionScreen(onNext: next)
        case .graph: GraphScreen(onNext: next)
        case .streak: StreakScreen(onNext: next)
        case .reminder: ReminderScreen(onNext: next)
        case .widget: WidgetScreen(onNext: next)
        case .loading: LoadingScreen(onNext: next)
        case .plan: PlanScreen(onNext: next)
        case .socialProof: SocialProofScreen(onNext: next)
        case .account: AccountScreen(onBack: back, onNext: next)
        case .gift:
            if let offer { GiftScreen(offer: offer, onNext: next) }
        case .noCommitment:
            if let offer { NoCommitmentScreen(offer: offer, onNext: next) }
        case .trial:
            if let offer { TrialScreen(offer: offer, extendedOffer: extendedOffer, onFinish: finish) }
        }
    }
}

// MARK: - Glide between two screens

private struct GlideEffect: ViewModifier {
    let x: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity)
    }
}

extension AnyTransition {
    /// The outgoing screen fades out quickly while gliding, the next one comes in from the opposite side and settles gently.
    static func onbGlide(forward: Bool) -> AnyTransition {
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: AnyTransition
                .modifier(active: GlideEffect(x: 48 * side, opacity: 0), identity: GlideEffect(x: 0, opacity: 1))
                .animation(.glide.delay(0.1)),
            removal: AnyTransition
                .modifier(active: GlideEffect(x: -32 * side, opacity: 0), identity: GlideEffect(x: 0, opacity: 1))
                .animation(.easeIn(duration: 0.18))
        )
    }
}

// MARK: - Development helpers

/// Launch arguments (Debug builds only) to open a screen directly:
/// `-onbStep graph`, `-onbName Max`, `-onbPreviewOffer YES` (full list in the README).
enum OnboardingDebug {
    /// True in a Debug build.
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var startStep: OnbStep? {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "onbStep") else { return nil }
        return OnbStep.allCases.first { "\($0)" == name }
        #else
        return nil
        #endif
    }

    /// Sample offer, to view the trial screens without a loaded StoreKit product.
    static func previewOffer(days: Int) -> TrialOffer? {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "onbPreviewOffer") else { return nil }
        return TrialOffer(previewDays: days)
        #else
        return nil
        #endif
    }

    /// True if the launch argument `-<key> YES` is present (always false outside Debug).
    static func flag(_ key: String) -> Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }

    /// Integer passed as a launch argument (`-<key> 2`), 0 by default and outside Debug.
    static func int(_ key: String) -> Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: key)
        #else
        return 0
        #endif
    }

    /// Prepares a sample profile when a screen is opened directly.
    static func prepare(_ profile: inout UserStore.Profile) {
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "skipOnboarding") {
            profile.onboarded = true
            return
        }
        guard defaults.string(forKey: "onbStep") != nil else { return }
        profile.onboarded = false
        if let name = defaults.string(forKey: "onbName") { profile.firstName = name }
        if profile.flashKnown.isEmpty {
            profile.flashKnown = Array(FlashCard.all.prefix(4).map(\.id))
        }
        #endif
    }
}

// MARK: - Screen templates

/// Template for question screens: title, content, button. The top bar is handled by `OnboardingFlow`.
/// The content scrolls if the screen is too small; the button always stays visible.
struct OnbScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    /// If true, the Mona Lisa asks the question, in a speech bubble.
    var spoken: Bool = false
    var mascotSize: CGFloat = 92
    var cta: String = "Continue"
    var ctaEnabled: Bool = true
    let onNext: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

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
            .padding(.horizontal, 24)
            .padding(.bottom, secondaryTitle == nil ? 16 : 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
    }

    @ViewBuilder
    private var header: some View {
        if spoken {
            MascotBubble(mascotSize: mascotSize) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.figtree(23, .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.figtree(15))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .enter()
        } else {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .enter()
        }
    }
}

/// Template for "story" screens: an illustration, a strong line, a button.
struct StoryScaffold: View {
    let image: String
    var tag: String? = nil
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continue"
    let onNext: () -> Void

    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // The illustration breathes slowly while you read.
            ArtImage(name: image, zoom: drift ? 1.09 : 1)
                .frame(minHeight: 180, maxHeight: 330)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .enter()

            VStack(spacing: 12) {
                if let tag {
                    TagPill(text: tag).enter(1)
                }
                Text(title)
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .enter(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.figtree(17))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(3.5)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, 28)

            Spacer(minLength: 16)

            Button(cta) { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

/// Template for screens with a large edge-to-edge illustration at the top.
struct HeroScaffold<Content: View>: View {
    let image: String
    var imageHeight: CGFloat = 410
    var cta: String = "Continue"
    let onNext: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ArtImage(name: image, zoom: drift ? 1.07 : 1)
                .frame(height: imageHeight)
                .clipShape(ArcHeaderShape())
                .ignoresSafeArea(edges: .top)

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
        .background(Palette.bg)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}
