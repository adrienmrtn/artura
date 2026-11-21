import SwiftUI

// MARK: 1 · Bienvenue

struct WelcomeScreen: View {
    let onNext: () -> Void
    let onLogin: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_hero", imageHeight: 470, cta: "Commencer", onNext: onNext,
                     secondaryTitle: "J'ai déjà un compte", onSecondary: onLogin) {
            Text("Artura").font(.figtree(15, .semibold)).foregroundStyle(Palette.blueText).appearUp(0.1)
            Text("Un chef-d'œuvre par jour").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Cinq minutes pour regarder, comprendre et retenir.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
        }
    }
}

// MARK: 2 · Promesse (lente, bloc par bloc)

struct PromiseScreen: View {
    let onNext: () -> Void
    @State private var shown = 0

    private let rows: [(String, String, String)] = [
        ("art_impression", "Une œuvre par jour", "Son histoire en 2 minutes, à lire ou à écouter."),
        ("ill_zoom", "Des mini-jeux", "Une minute de jeu pour retenir ce que tu viens de voir."),
        ("ill_musee", "Des parcours", "Les grands courants, leçon après leçon, à ton rythme.")
    ]
    private let pace = 1.6

    var body: some View {
        SlowScreen(duration: 1.2 + Double(rows.count) * pace + 0.4, onNext: onNext) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voici ce qui t'attend").font(.aTitle).foregroundStyle(Palette.ink)
                    Text("Trois petites choses, chaque jour.").font(.aBody).foregroundStyle(Palette.muted)
                }
                .opacity(shown >= 1 ? 1 : 0)
                .offset(y: shown >= 1 ? 0 : 12)

                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 14) {
                        ArtImage(name: row.0).frame(width: 104, height: 120)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.1).font(.aCardTitle).foregroundStyle(Palette.ink)
                            Text(row.2).font(.aSmall).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, 14)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(shown >= i + 2 ? 1 : 0)
                    .offset(y: shown >= i + 2 ? 0 : 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
        }
        .onAppear {
            for i in 1...(rows.count + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i - 1) * pace) {
                    withAnimation(.easeOut(duration: 1.1)) { shown = i }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: 3 · Tu es…

struct GenderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(number: OnbStep.gender.number, onBack: onBack, title: "Tu es…",
                    subtitle: "Pour accorder nos messages : « prêt » ou « prête » ?",
                    ctaEnabled: user.profile.gender != nil, onNext: onNext) {
            HStack(spacing: 12) {
                portrait("ill_av1", "Une femme", "femme")
                portrait("ill_av2", "Un homme", "homme")
            }
            .appearUp(0.1)
            VStack(spacing: 10) {
                OptionRow(title: "Autre", selected: user.profile.gender == "autre") { user.profile.gender = "autre" }
                OptionRow(title: "Je préfère ne pas le dire", selected: user.profile.gender == "na") { user.profile.gender = "na" }
            }
            .appearUp(0.2)
        }
    }

    private func portrait(_ image: String, _ label: String, _ value: String) -> some View {
        let selected = user.profile.gender == value
        return Button {
            Haptics.selection()
            user.profile.gender = value
        } label: {
            VStack(spacing: 12) {
                ArtImage(name: image).frame(height: 150)
                Text(label).font(.figtree(17, .semibold)).foregroundStyle(Palette.ink)
            }
            .padding(.bottom, 14)
            .background(selected ? Palette.blueSelected : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                if selected { CheckBadge().padding(8).transition(.scale) }
            }
            .scaleEffect(selected ? 1.01 : 1)
        }
        .buttonStyle(.pressable)
        .animation(.bouncy, value: selected)
    }
}

// MARK: 5 · Artura va t'aider (l'œil)

struct HelpScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_oeil", onBack: onBack, onNext: onNext) {
            TagPill(text: "Artura va t'aider").appearUp(0.1)
            Text("Regarder, ça s'apprend").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Personne ne naît en sachant lire un tableau. Chaque jour, on te montre où poser les yeux : un détail, une couleur, un geste.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
            Text("Passer vite devant un tableau n'a rien d'une faute. On va juste te donner de quoi t'arrêter.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.4)
        }
    }
}

// MARK: Avis et note

struct ReviewsScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var stars = 0

    // TODO: remplacer par de vrais avis et la vraie note de la fiche App Store avant la mise en ligne.
    private let reviews = [
        "« Cinq minutes le matin, et je regarde enfin les tableaux autrement. »",
        "« Avec les petits jeux, je retiens vraiment les noms et les dates. »",
        "« Je n'y connaissais rien. Maintenant j'attends la notification. »"
    ]

    var body: some View {
        OnbScaffold(onBack: onBack, title: "Tu n'es pas \(alone) à t'y mettre", onNext: onNext) {
            HStack(spacing: 16) {
                Text("4,8").font(.figtree(52, .semibold)).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.yellow)
                                .scaleEffect(i < stars ? 1 : 0.7)
                                .opacity(i < stars ? 1 : 0)
                        }
                    }
                    Text("sur 5 · App Store").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.blueSoft))
            .appearUp(0.05)

            Text("Ce qu'ils en disent").font(.aHeading).foregroundStyle(Palette.ink)

            VStack(spacing: 12) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { i, review in
                    Text(review)
                        .font(.figtree(15, .medium))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                        .appearUp(0.2 + 0.1 * Double(i))
                }
            }
        }
        .onAppear {
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * Double(i)) {
                    withAnimation(.bouncy) { stars = i }
                    Haptics.soft()
                }
            }
        }
    }

    @EnvironmentObject private var user: UserStore
    private var alone: String { user.agree("le seul", "la seule") }
}
