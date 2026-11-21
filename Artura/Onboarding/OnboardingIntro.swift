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
                      subtitle: "Artura a été créé pour les amoureux de l'art.",
                      onNext: onNext)
    }
}

// MARK: Au musée aussi

struct PhotoScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_photo",
                      tag: "Et au musée ?",
                      title: "Prends les œuvres en photo, demande des explications.",
                      subtitle: "Et garde dans ta collection celles que tu veux retenir.",
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

struct QuestionsIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotScaffold(title: "Quelques questions pour mieux te connaître.",
                       subtitle: "Moins d'une minute, pour un programme à ta mesure.",
                       cta: "C'est parti", onNext: onNext)
    }
}

struct TestIntroScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "Très bien, \(name). Voyons ce que tu sais déjà."
        }
        return "Très bien. Voyons ce que tu sais déjà."
    }

    var body: some View {
        MascotScaffold(title: title,
                       subtitle: "Sept tableaux, du plus célèbre au plus pointu.",
                       cta: user.agree("Je suis prêt", "Je suis prête"), onNext: onNext)
    }
}

// MARK: Comprendre, pas seulement apprendre (texte qui s'écrit)

struct UnderstandScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            MascotBubble(mascotSize: 150) {
                TypewriterText(text: "Avec Artura, tu n'apprends pas seulement des noms. Tu comprends l'histoire derrière les tableaux, et ce qu'ils veulent dire.")
            }
            .enter()

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
            .padding(.top, 22)
            .enter(4)

            Spacer(minLength: 16)
            Spacer(minLength: 0)

            Button("Commencer la visite") { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}
