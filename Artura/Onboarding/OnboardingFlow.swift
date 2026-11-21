import SwiftUI

enum OnbStep: Int, CaseIterable {
    // 1 · La promesse
    case welcome, daily, pocketMuseum, photo, quotes
    // 2 · Faire connaissance
    case questionsIntro, name, gender, motivation, arts, recognize, knowledge, museum
    // 3 · Le test
    case testIntro, flashTest, flashResult
    // 4 · La démonstration
    case understand, lesson
    // 5 · Le déclic : ce temps peut devenir connaissance
    case phoneTime, phoneResult, projection, graph
    // 6 · L'engagement
    case streak, reminder, loading, plan, account
    // 7 · Le cadeau : l'essai gratuit
    case gift, noCommitment, trial

    /// Écrans qui affichent la barre commune (retour + progression).
    /// Les autres sont en pleine page ou ont leur propre en-tête.
    var showsBar: Bool {
        switch self {
        case .welcome, .lesson, .loading, .account, .gift, .noCommitment, .trial: return false
        default: return true
        }
    }

    /// Avancement dans l'onboarding, de 0 à 1 (la barre est pleine au moment du compte).
    var progress: Double {
        min(1, Double(rawValue) / Double(OnbStep.account.rawValue))
    }

    /// Écran affiché quand on revient en arrière (nil = pas de retour possible).
    var previous: OnbStep? {
        switch self {
        case .welcome, .gift, .noCommitment, .trial: return nil
        // Le chargement se rejoue tout seul : on le saute au retour.
        case .plan: return .reminder
        default: return OnbStep(rawValue: rawValue - 1)
        }
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var pro: ProStore

    @State private var step: OnbStep = OnboardingDebug.startStep ?? .welcome
    /// Sens du dernier déplacement : il décide de quel côté les écrans glissent.
    @State private var forward = true
    /// Vrai pendant un changement d'écran : un double appui ne saute pas d'étape.
    @State private var moving = false
    /// Vrai si on est arrivé à l'écran de compte par « J'ai déjà un compte ».
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

    /// Offre d'essai présentée à la fin (nil tant que le produit n'est pas chargé).
    private var offer: TrialOffer? {
        TrialOffer(pro.yearly) ?? OnboardingDebug.previewOffer(days: 3)
    }

    /// Offre de dernière minute : le même abonnement avec un essai plus long.
    private var extendedOffer: TrialOffer? {
        TrialOffer(pro.yearlyExtended) ?? OnboardingDebug.previewOffer(days: 7)
    }

    // MARK: Navigation

    private func go(_ target: OnbStep) {
        guard !moving, target != step else { return }
        moving = true
        let isForward = target.rawValue > step.rawValue
        if isForward != forward {
            // Le sens change : on laisse l'écran courant l'apprendre avant de le faire sortir.
            forward = isForward
            DispatchQueue.main.async { move(to: target) }
        } else {
            move(to: target)
        }
    }

    private func move(to target: OnbStep) {
        withAnimation(.glide) { step = target }
        // Petit « toc » quand le nouvel écran se pose.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Haptics.soft() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { moving = false }
    }

    private func next() {
        // Après le compte vient le cadeau, s'il y a bien une offre d'essai à présenter.
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

    // MARK: Écrans

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome:
            WelcomeScreen(onNext: next, onLogin: {
                loginShortcut = true
                go(.account)
            })
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
        case .understand: UnderstandScreen(onNext: next)
        case .lesson:
            if let course {
                // Un extrait du cours : le début et une seule interaction sur le tableau.
                LessonView(artwork: course, pill: "Ta première visite guidée",
                           blocks: course.previewLesson, finishTitle: "Terminer la visite",
                           onSkip: next, onBack: back) {
                    user.profile.firstCourse = course.id
                    user.markOpened(course.id)
                    user.markPlayedToday()
                    next()
                }
            }
        case .phoneTime: PhoneTimeScreen(onNext: next)
        case .phoneResult: PhoneResultScreen(onNext: next)
        case .projection: ProjectionScreen(onNext: next)
        case .graph: GraphScreen(onNext: next)
        case .streak: StreakScreen(onNext: next)
        case .reminder: ReminderScreen(onNext: next)
        case .loading: LoadingScreen(onNext: next)
        case .plan: PlanScreen(onNext: next)
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

// MARK: - Glissement entre deux écrans

private struct GlideEffect: ViewModifier {
    let x: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity)
    }
}

extension AnyTransition {
    /// L'écran sortant s'efface vite en glissant, le suivant arrive du côté opposé et se pose en douceur.
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

// MARK: - Aides de développement

/// Arguments de lancement (builds Debug uniquement) pour ouvrir directement un écran :
/// `-onbStep graph`, `-onbName Max`, `-onbPreviewOffer YES`.
enum OnboardingDebug {
    static var startStep: OnbStep? {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "onbStep") else { return nil }
        return OnbStep.allCases.first { "\($0)" == name }
        #else
        return nil
        #endif
    }

    /// Offre d'exemple, pour voir les écrans d'essai sans produit StoreKit chargé.
    static func previewOffer(days: Int) -> TrialOffer? {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "onbPreviewOffer") else { return nil }
        return TrialOffer(previewDays: days)
        #else
        return nil
        #endif
    }

    /// Vrai si l'argument de lancement `-<clé> YES` est présent (toujours faux hors Debug).
    static func flag(_ key: String) -> Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }

    /// Prépare un profil d'exemple quand un écran est ouvert directement.
    static func prepare(_ profile: inout UserStore.Profile) {
        #if DEBUG
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "onbStep") != nil else { return }
        profile.onboarded = false
        if let name = defaults.string(forKey: "onbName") { profile.firstName = name }
        if profile.flashKnown.isEmpty {
            profile.flashKnown = Array(FlashCard.all.prefix(4).map(\.id))
        }
        #endif
    }
}

// MARK: - Gabarits d'écran

/// Gabarit des écrans de question : titre, contenu, bouton. La barre du haut est gérée par `OnboardingFlow`.
/// Le contenu défile si l'écran est trop petit ; le bouton reste toujours visible.
struct OnbScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    /// Si vrai, c'est la Joconde qui pose la question, dans une bulle.
    var spoken: Bool = false
    var cta: String = "Continuer"
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
            MascotBubble(mascotSize: 104) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.aTitleSmall)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.aBody)
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

/// Gabarit des écrans « récit » : une illustration, une phrase forte, un bouton.
struct StoryScaffold: View {
    let image: String
    var tag: String? = nil
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continuer"
    let onNext: () -> Void

    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // L'illustration respire lentement pendant la lecture.
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

/// Gabarit des écrans où la Joconde prend la parole : le personnage, sa bulle, un bouton.
struct MascotScaffold<Extra: View>: View {
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continuer"
    let onNext: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            MascotBubble(mascotSize: 168) {
                Text(title)
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enter()
            if let subtitle {
                Text(subtitle)
                    .font(.figtree(17))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .enter(3)
            }
            extra()
            Spacer(minLength: 16)
            Spacer(minLength: 0)
            Button(cta) { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}

extension MascotScaffold where Extra == EmptyView {
    init(title: String, subtitle: String? = nil, cta: String = "Continuer", onNext: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, cta: cta, onNext: onNext) { EmptyView() }
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
