import SwiftUI

// MARK: Bienvenue

struct WelcomeScreen: View {
    let onNext: () -> Void
    let onLogin: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_hero", imageHeight: 460, cta: "Commencer", onNext: onNext,
                     secondaryTitle: "J'ai déjà un compte", onSecondary: onLogin) {
            Text("ARTURA")
                .font(.figtree(13, .bold))
                .tracking(3)
                .foregroundStyle(Palette.blue)
                .enter(0)
            Text("Apprends enfin l'art")
                .font(.figtree(36, .bold))
                .foregroundStyle(Palette.ink)
                .enter(1)
            Text("5 minutes par jour, des sessions pensées pour toi.")
                .font(.figtree(17))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .enter(2.5)
        }
    }
}

// MARK: Une œuvre par jour (mur de tableaux)

struct DailyScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FloatingWall()
                .enter()

            VStack(spacing: 12) {
                Text("Une œuvre par jour")
                    .font(.figtree(34, .bold))
                    .foregroundStyle(Palette.ink)
                    .enter(2)
                Text("Cultive-toi sans t'en rendre compte.")
                    .font(.figtree(17))
                    .foregroundStyle(Palette.muted)
                    .enter(3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 26)

            HStack(spacing: 12) {
                proof(value: SocialProof.learners, label: "personnes apprennent déjà") {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                }
                proof(value: SocialProof.rating, label: "de note moyenne") {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.yellow)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .enter(5)

            Spacer(minLength: 16)

            Button("Continuer") { onNext() }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
    }

    private func proof<Mark: View>(value: String, label: String, @ViewBuilder mark: () -> Mark) -> some View {
        VStack(spacing: 4) {
            mark().frame(height: 16)
            Text(value)
                .font(.figtree(26, .bold))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.aCaption)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: Un musée dans ta poche

struct PocketMuseumScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_musee",
                      title: "Artura, c'est un musée dans ta poche.",
                      subtitle: "Créé pour les amoureux de l'art, et pour ceux qui veulent le devenir.",
                      onNext: onNext)
    }
}

// MARK: Au musée aussi

struct PhotoScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_photo",
                      tag: "Et au musée ?",
                      title: "Prends une œuvre en photo, Artura te l'explique.",
                      subtitle: "Et tu gardes dans ta collection celles que tu veux retenir.",
                      onNext: onNext)
    }
}

// MARK: Citations : pourquoi Artura

struct Quote: Identifiable {
    let image: String
    let text: String
    let author: String
    let role: String
    var id: String { author }

    // Citations à faire vérifier (source et traduction) avant la mise en ligne.
    static let all: [Quote] = [
        Quote(image: "portrait_klee", text: "L'art ne reproduit pas le visible, il rend visible.", author: "Paul Klee", role: "Peintre"),
        Quote(image: "portrait_nietzsche", text: "Nous avons l'art pour ne pas mourir de la vérité.", author: "Friedrich Nietzsche", role: "Philosophe"),
        Quote(image: "portrait_proust", text: "Par l'art seulement, nous pouvons sortir de nous.", author: "Marcel Proust", role: "Écrivain")
    ]
}

struct QuotesScreen: View {
    let onNext: () -> Void
    @State private var shown = 0

    private let quotes = Quote.all

    var body: some View {
        OnbScaffold(title: "Voilà pourquoi on a créé Artura",
                    subtitle: "L'art est intemporel. Eux le disaient déjà.",
                    onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                    HStack(alignment: .top, spacing: 14) {
                        ArtImage(name: quote.image, anchor: .top)
                            .saturation(0)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("« \(quote.text) »")
                                .font(.serif(18, .medium))
                                .italic()
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(quote.author) · \(quote.role)")
                                .font(.aCaption)
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown ? 0 : 18)
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            // Les citations arrivent une à une, sans rien bloquer.
            for i in 1...quotes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i - 1) * 0.6) {
                    withAnimation(.settle) { shown = max(shown, i) }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: La Joconde prend la parole

/// « Salut, moi c'est Artura » : le personnage se présente, juste après l'accueil.
struct HelloScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "Salut, moi c'est Artura. Chaque jour, je te raconte un chef-d'œuvre et l'histoire qu'il cache."
        ], cta: "Salut Artura !", mascotSize: 190, onNext: onNext)
    }
}

struct QuestionsIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "Faisons connaissance. Quelques questions, moins d'une minute, pour préparer ton programme."
        ], cta: "C'est parti", onNext: onNext)
    }
}

struct TestIntroScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private var line: String {
        let start: String
        if let name = user.profile.firstName, !name.isEmpty {
            start = "Très bien, \(name)."
        } else {
            start = "Très bien."
        }
        return "\(start) Voyons ce que tu sais déjà : sept tableaux, du plus célèbre au plus difficile."
    }

    var body: some View {
        MascotTalkScreen(lines: [line], cta: user.agree("Je suis prêt", "Je suis prête"), onNext: onNext)
    }
}

// MARK: Avant la visite guidée : ce qu'Artura apporte

struct UnderstandScreen: View {
    /// Le tableau de la visite guidée qui suit.
    let artwork: Artwork?
    let onNext: () -> Void

    private var lines: [String] {
        let subject = artwork.map { "\($0.title) de \($0.artist)" } ?? "un tableau"
        return [
            "Avec moi, tu n'apprends pas seulement des noms. Tu comprends l'histoire derrière chaque tableau, et ce qu'il veut dire.",
            "Je te présente une œuvre par jour, avec toute son histoire. Jour après jour, tu connaîtras toutes les grandes œuvres.",
            "Mon but : rendre la culture accessible à tout le monde, de façon simple et ludique. L'art est un patrimoine que chacun mérite de connaître.",
            "Regardons ensemble \(subject). Connais-tu toute son histoire ? Laisse-toi guider : la visite est interactive."
        ]
    }

    var body: some View {
        MascotTalkScreen(lines: lines, cta: "Commencer la visite", onNext: onNext) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ta première visite guidée · 2 min")
                    .font(.figtree(14, .semibold))
            }
            .foregroundStyle(Palette.blue)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Palette.sand))
        }
    }
}

// MARK: Après la visite guidée

struct AfterLessonScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "Voilà comment tu apprendras désormais. Avant de finir, préparons ton programme."
        ], cta: "Préparer mon programme", onNext: onNext)
    }
}
