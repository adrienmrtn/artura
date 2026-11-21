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

// MARK: 2 · Promesse

struct PromiseScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    private let rows: [(String, String, String)] = [
        ("art_impression", "Une œuvre par jour", "Son histoire en 2 minutes, à lire ou à écouter."),
        ("ill_zoom", "Des mini-jeux", "Une minute de jeu pour retenir ce que tu viens de voir."),
        ("ill_musee", "Des parcours", "Les grands courants, leçon après leçon, à ton rythme.")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.promise.number, onBack: onBack, title: "Voici ce qui t'attend",
                    subtitle: "Trois petites choses, chaque jour.", onNext: onNext) {
            VStack(spacing: 16) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 14) {
                        ArtImage(name: row.0).frame(width: 104, height: 112)
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
                    .appearUp(0.1 + Double(i) * 0.12)
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

// MARK: 4 · Regarder

struct LookScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let options = [
        "Je passe vite, sans trop savoir quoi regarder",
        "J'aime bien, sans pouvoir dire pourquoi",
        "Je lis le cartel, puis j'oublie tout",
        "Je pourrais y rester des heures"
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.look.number, onBack: onBack,
                    title: "Devant un tableau, il se passe quoi pour toi ?",
                    subtitle: "Sois honnête, personne ne regarde.",
                    ctaEnabled: user.profile.lookAnswer != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    OptionRow(title: option, selected: user.profile.lookAnswer == option) {
                        user.profile.lookAnswer = option
                    }
                    .appearUp(0.08 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: 5 · Artura va t'aider (l'œil)

struct HelpScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_oeil", number: OnbStep.help.number, onBack: onBack, onNext: onNext) {
            TagPill(text: "Artura va t'aider").appearUp(0.1)
            Text("Regarder, ça s'apprend").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Personne ne naît en sachant lire un tableau. Chaque jour, on te montre où poser les yeux : un détail, une couleur, un geste.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
            Text("Passer vite devant un tableau n'a rien d'une faute. On va juste te donner de quoi t'arrêter.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.4)
        }
    }
}

// MARK: 6 · Comprendre

struct UnderstandScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    private let options = [
        "Rarement, il me manque les clés",
        "Parfois, pour les œuvres célèbres",
        "Souvent, mais j'aimerais aller plus loin"
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.understand.number, onBack: onBack,
                    title: "Et comprendre ce que tu regardes ?",
                    subtitle: "Qui l'a peint, quand, et pourquoi ça compte.",
                    ctaEnabled: user.profile.understandAnswer != nil, onNext: onNext) {
            ArtImage(name: "art_baiser", anchor: UnitPoint(x: 0.5, y: 0.3))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .appearUp(0.1)
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    OptionRow(title: option, selected: user.profile.understandAnswer == option) {
                        user.profile.understandAnswer = option
                    }
                    .appearUp(0.15 + 0.08 * Double(i))
                }
            }
        }
    }
}

// MARK: 7 · À quoi ça sert (carrousel)

struct WhyScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var page = 0

    private let slides: [(String, String, String)] = [
        ("art_nympheas", "Ralentir", "Quelques minutes devant une seule image, sans rien faire d'autre."),
        ("art_vague", "Mieux voir", "On remarque plus de choses quand on sait quoi chercher."),
        ("art_perle", "Se relier", "Derrière chaque tableau, quelqu'un qui a vécu, aimé, douté.")
    ]

    var body: some View {
        OnbScaffold(number: OnbStep.why.number, onBack: onBack,
                    title: "Au fait, à quoi ça sert, l'art ?",
                    subtitle: "À rien d'urgent. C'est justement l'intérêt.",
                    cta: page < slides.count - 1 ? "Suivant" : "Je suis \(partant)",
                    onNext: advance) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { i, slide in
                    VStack(alignment: .leading, spacing: 14) {
                        ArtImage(name: slide.0)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slide.1).font(.figtree(24, .semibold)).foregroundStyle(Palette.ink)
                            Text(slide.2).font(.aBody).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 390)
            .onChange(of: page) { _, _ in Haptics.selection() }

            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Palette.ink : Color(hex: 0xB9B4B0))
                        .frame(width: i == page ? 24 : 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: page)
        }
    }

    @EnvironmentObject private var user: UserStore
    private var partant: String { user.agree("partant", "partante") }

    private func advance() {
        if page < slides.count - 1 {
            withAnimation(.gentle) { page += 1 }
        } else {
            onNext()
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
