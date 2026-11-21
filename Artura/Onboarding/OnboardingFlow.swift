import SwiftUI

enum OnbStep: Int, CaseIterable {
    case welcome, daily, builtFor, quotes
    case questionsIntro, name, why, recognize, knowledge, museum
    case testIntro, flashTest, flashResult
    case lesson
    case doomscroll, projection, graph
    case reminder, loading, plan, account

    /// Écrans qui affichent la barre commune (retour + progression).
    /// Les autres sont en pleine page ou ont leur propre en-tête.
    var showsBar: Bool {
        switch self {
        case .welcome, .lesson, .loading, .account: return false
        default: return true
        }
    }

    /// Avancement dans l'onboarding, de 0 à 1.
    var progress: Double {
        Double(rawValue) / Double(Self.allCases.count - 1)
    }

    /// Écran affiché quand on revient en arrière (nil = pas de retour possible).
    var previous: OnbStep? {
        switch self {
        case .welcome: return nil
        // Le chargement se rejoue tout seul : on le saute au retour.
        case .plan: return .reminder
        default: return OnbStep(rawValue: rawValue - 1)
        }
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore

    @State private var step: OnbStep = .welcome
    /// Vrai si on est arrivé à l'écran de compte par « J'ai déjà un compte ».
    @State private var loginShortcut = false

    var body: some View {
        VStack(spacing: 0) {
            if step.showsBar {
                bar.transition(.opacity)
            }
            screen
                .id(step)
                .transition(.onbScreen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    /// Barre commune : elle reste en place d'un écran à l'autre, seule la progression avance.
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
            .accessibilityLabel("Retour")
            ProgressTrack(value: step.progress)
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var course: Artwork? {
        content.artwork(user.profile.firstCourse) ?? content.artwork("nuit") ?? content.artworks.first
    }

    private func go(_ target: OnbStep) {
        withAnimation(.easeInOut(duration: 0.3)) { step = target }
        // Petit « toc » quand le nouvel écran se pose.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Haptics.soft() }
    }

    private func next() {
        if let target = OnbStep(rawValue: step.rawValue + 1) {
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

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome: WelcomeScreen(onNext: next, onLogin: {
            loginShortcut = true
            go(.account)
        })
        case .daily: DailyScreen(onNext: next)
        case .builtFor: BuiltForScreen(onNext: next)
        case .quotes: QuotesScreen(onNext: next)
        case .questionsIntro: QuestionsIntroScreen(onNext: next)
        case .name: NameScreen(onNext: next)
        case .why: WhyScreen(onNext: next)
        case .recognize: RecognizeScreen(onNext: next)
        case .knowledge: KnowledgeScreen(onNext: next)
        case .museum: MuseumScreen(onNext: next)
        case .testIntro: TestIntroScreen(onNext: next)
        case .flashTest: FlashTestScreen(onNext: next)
        case .flashResult: FlashResultScreen(onNext: next)
        case .lesson:
            if let course {
                LessonView(artwork: course, pill: "Ton premier cours", onBack: back) {
                    user.profile.firstCourse = course.id
                    user.completeLesson(course.id)
                    next()
                }
            }
        case .doomscroll: DoomscrollScreen(onNext: next)
        case .projection: ProjectionScreen(onNext: next)
        case .graph: GraphScreen(onNext: next)
        case .reminder: ReminderScreen(onNext: next)
        case .loading: LoadingScreen(onNext: next)
        case .plan: PlanScreen(onNext: next)
        case .account: AccountScreen(onBack: back, onNext: next)
        }
    }
}

extension AnyTransition {
    /// L'écran sortant s'efface d'abord, le suivant monte ensuite : jamais deux textes superposés.
    static var onbScreen: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10))
                .animation(.easeOut(duration: 0.3).delay(0.12)),
            removal: .opacity.animation(.easeIn(duration: 0.12))
        )
    }
}

// MARK: - Gabarits d'écran

/// Gabarit des écrans de question : titre, contenu, bouton. La barre du haut est gérée par `OnboardingFlow`.
struct OnbScaffold<Content: View>: View {
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
        .padding(.top, 12)
        .padding(.bottom, secondaryTitle == nil ? 16 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}

/// Gabarit des écrans « récit » : une illustration, une phrase forte, un bouton.
struct StoryScaffold: View {
    let image: String
    var tag: String? = nil
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continuer"
    let onNext: () -> Void

    @State private var drift = false

    var body: some View {
        VStack(spacing: 0) {
            // L'illustration respire lentement pendant la lecture.
            ArtImage(name: image, zoom: drift ? 1.08 : 1)
                .frame(minHeight: 180, maxHeight: 330)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .appearUp()

            VStack(spacing: 12) {
                if let tag {
                    TagPill(text: tag).appearUp(0.2)
                }
                Text(title)
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .appearUp(0.3)
                if let subtitle {
                    Text(subtitle)
                        .font(.aBody)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .appearUp(0.5)
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
        .background(Color.white)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

/// Gabarit des écrans à grande illustration en haut, bord à bord.
struct HeroScaffold<Content: View>: View {
    let image: String
    var imageHeight: CGFloat = 410
    var cta: String = "Continuer"
    let onNext: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ArtImage(name: image)
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
        .background(Color.white)
    }
}
