import SwiftUI

// MARK: Bienvenue

struct WelcomeScreen: View {
    let onNext: () -> Void
    let onLogin: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_hero", imageHeight: 470, cta: "Commencer", onNext: onNext,
                     secondaryTitle: "J'ai déjà un compte", onSecondary: onLogin) {
            Text("Artura").font(.figtree(15, .semibold)).foregroundStyle(Palette.blueText).appearUp(0.1)
            Text("Apprends enfin l'art").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("5 minutes par jour, des sessions pensées pour toi.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
        }
    }
}

// MARK: Une œuvre par jour

struct DailyScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_engagement",
                      title: "Une œuvre par jour",
                      subtitle: "Tu te cultives sans t'en rendre compte.",
                      onNext: onNext)
    }
}

// MARK: Pour qui Artura existe

struct BuiltForScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_musee",
                      title: "Le musée, sans avoir à y aller",
                      subtitle: "Artura est né pour celles et ceux qui veulent apprendre l'art, mais qui n'ont pas le temps d'aller au musée.",
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("« \(quote.text) »")
                                .font(.figtree(17, .semibold))
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
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown ? 0 : 14)
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            // Les citations arrivent une à une, sans rien bloquer.
            for i in 1...quotes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i - 1) * 0.55) {
                    withAnimation(.easeOut(duration: 0.5)) { shown = max(shown, i) }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: Transitions entre les parties

struct QuestionsIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_oeil",
                      title: "Quelques questions pour mieux te connaître",
                      subtitle: "Moins d'une minute, pour un programme à ta mesure.",
                      cta: "C'est parti",
                      onNext: onNext)
    }
}

struct TestIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_zoom",
                      title: "Très bien. Voyons ce que tu sais déjà.",
                      subtitle: "Sept tableaux, du plus célèbre au plus pointu.",
                      cta: "Allons-y",
                      onNext: onNext)
    }
}

// MARK: Plutôt que de scroller

struct DoomscrollScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_phone",
                      title: "Plutôt que de scroller sans fin, apprends l'art.",
                      subtitle: "Nourris ton esprit des plus grandes œuvres de l'humanité.",
                      onNext: onNext)
    }
}
