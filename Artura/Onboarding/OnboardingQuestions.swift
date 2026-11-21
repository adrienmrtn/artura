import SwiftUI

// MARK: Ton prénom

struct NameScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        OnbScaffold(title: "Comment tu t'appelles ?",
                    subtitle: "Pour qu'on sache à qui on parle.",
                    ctaEnabled: !trimmed.isEmpty, onNext: save) {
            TextField("Ton prénom", text: $name)
                .font(.figtree(24, .semibold))
                .foregroundStyle(Palette.ink)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { if !trimmed.isEmpty { save() } }
                .padding(.horizontal, 18)
                .frame(height: 68)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(focused ? Palette.blue : Palette.line, lineWidth: focused ? 2 : 1)
                )
                .animation(.snappy, value: focused)
                .enter(2)
        }
        .onAppear {
            name = user.profile.firstName ?? ""
            // Le clavier monte une fois l'écran posé.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { focused = true }
        }
    }

    private func save() {
        user.profile.firstName = trimmed
        focused = false
        onNext()
    }
}

// MARK: Tu es…

struct GenderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "Enchantée, \(name) ! Tu es…"
        }
        return "Tu es…"
    }

    var body: some View {
        OnbScaffold(title: title,
                    subtitle: "Pour accorder nos messages : « prêt » ou « prête » ?",
                    ctaEnabled: user.profile.gender != nil, onNext: onNext) {
            HStack(spacing: 12) {
                portrait("ill_av1", "Une femme", "femme")
                portrait("ill_av2", "Un homme", "homme")
            }
            .enter(2)
            VStack(spacing: 10) {
                ChoiceRow(title: "Autre", selected: user.profile.gender == "autre") {
                    user.profile.gender = "autre"
                }
                ChoiceRow(title: "Je préfère ne pas le dire", selected: user.profile.gender == "na") {
                    user.profile.gender = "na"
                }
            }
            .enter(3.5)
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
            .background(selected ? Palette.sandLight : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Palette.blue : Palette.line, lineWidth: selected ? 3 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if selected { CheckBadge(color: Palette.blue).padding(8).transition(.scale.combined(with: .opacity)) }
            }
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Qu'est-ce qui t'amène ? (plusieurs réponses)

struct MotivationScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private let options: [(title: String, symbol: String)] = [
        ("Apprendre l'art", "paintpalette.fill"),
        ("Nourrir mon intelligence", "brain.head.profile"),
        ("Avoir de nouvelles choses à raconter", "bubble.left.and.bubble.right.fill"),
        ("Préparer un examen", "graduationcap.fill"),
        ("Pour le plaisir", "sparkles")
    ]

    private var chosen: [String] { user.profile.goals ?? [] }

    var body: some View {
        OnbScaffold(title: "Qu'est-ce qui t'amène ?",
                    subtitle: "Plusieurs réponses possibles.",
                    ctaEnabled: !chosen.isEmpty, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    ChoiceRow(title: option.title, symbol: option.symbol,
                              selected: chosen.contains(option.title), multiple: true) {
                        toggle(option.title)
                    }
                    .enter(Double(i) + 2)
                }
            }
        }
    }

    private func toggle(_ title: String) {
        var goals = chosen
        if let index = goals.firstIndex(of: title) {
            goals.remove(at: index)
        } else {
            goals.append(title)
        }
        user.profile.goals = goals
        // La première motivation reste « l'objectif » rappelé dans le programme.
        user.profile.goal = goals.first
    }
}

// MARK: Tes arts

struct ArtsScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private let arts: [(id: String, title: String, image: String, soon: Bool)] = [
        ("peinture", "Peinture", "ill_palette", false),
        ("sculpture", "Sculpture", "ill_sculpture", true),
        ("architecture", "Architecture", "ill_musee", true),
        ("photographie", "Photographie", "ill_photo", true)
    ]

    var body: some View {
        OnbScaffold(title: "Y a-t-il des arts que tu veux explorer en particulier ?",
                    subtitle: "Autant que tu veux. La peinture est prête, les autres arrivent.",
                    ctaEnabled: !user.profile.arts.isEmpty, onNext: onNext) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(arts.enumerated()), id: \.element.id) { i, art in
                    let selected = user.profile.arts.contains(art.id)
                    Button {
                        Haptics.selection()
                        if let at = user.profile.arts.firstIndex(of: art.id) {
                            user.profile.arts.remove(at: at)
                        } else {
                            user.profile.arts.append(art.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ArtImage(name: art.image)
                                .frame(height: 112)
                                .overlay(alignment: .topLeading) {
                                    if art.soon {
                                        Text("Bientôt")
                                            .font(.figtree(11, .semibold))
                                            .foregroundStyle(Palette.ink)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Palette.card))
                                            .padding(8)
                                    }
                                }
                            Text(art.title)
                                .font(.bodyStrong)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                        .background(selected ? Palette.sandLight : Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(selected ? Palette.blue : Palette.line, lineWidth: selected ? 3 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if selected { CheckBadge(color: Palette.blue).padding(8).transition(.scale.combined(with: .opacity)) }
                        }
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .enter(Double(i) * 0.7 + 2)
                }
            }
        }
    }
}

// MARK: Question à choix unique (gabarit commun)

struct ChoiceOption {
    let title: String
    var subtitle: String? = nil
}

struct ChoiceScreen: View {
    let title: String
    var subtitle: String? = nil
    let options: [ChoiceOption]
    @Binding var selection: String?
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(title: title, subtitle: subtitle, ctaEnabled: selection != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    ChoiceRow(title: option.title, subtitle: option.subtitle, selected: selection == option.title) {
                        selection = option.title
                    }
                    .enter(Double(i) + 2)
                }
            }
        }
    }
}

// MARK: Les œuvres qu'on ne sait pas nommer

struct RecognizeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: "Tu vois souvent des œuvres d'art que tu ne sais pas nommer ?",
                     subtitle: "Dans un film, sur une affiche, chez quelqu'un.",
                     options: [
                        ChoiceOption(title: "Tout le temps"),
                        ChoiceOption(title: "Ça m'arrive"),
                        ChoiceOption(title: "Rarement")
                     ],
                     selection: $user.profile.unknownArt, onNext: onNext)
    }
}

// MARK: Tes connaissances

struct KnowledgeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    // Le titre de l'option est aussi le niveau enregistré (affiché ensuite sur le profil).
    var body: some View {
        ChoiceScreen(title: "As-tu des connaissances précises en histoire de l'art ?",
                     subtitle: "Ça règle ton point de départ. Tu pourras changer.",
                     options: [
                        ChoiceOption(title: "Débutant", subtitle: "Je pars de zéro, et c'est très bien."),
                        ChoiceOption(title: "Amateur", subtitle: "Je connais quelques artistes et courants."),
                        ChoiceOption(title: "Connaisseur", subtitle: "Je distingue un Monet d'un Manet.")
                     ],
                     selection: $user.profile.level, onNext: onNext)
    }
}

// MARK: Le musée

struct MuseumScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: "Tu vas souvent au musée ?",
                     options: [
                        ChoiceOption(title: "Presque jamais"),
                        ChoiceOption(title: "Une ou deux fois par an"),
                        ChoiceOption(title: "Plusieurs fois par an"),
                        ChoiceOption(title: "Dès que je peux")
                     ],
                     selection: $user.profile.museumHabit, onNext: onNext)
    }
}

// MARK: Le temps passé sur ton téléphone

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    @State private var hours: Double = 4
    @State private var glow = false

    private var hoursLabel: String { formatHours(hours) }

    var body: some View {
        OnbScaffold(title: "Combien de temps par jour sur ton téléphone ?",
                    subtitle: "Regarde dans Réglages › Temps d'écran si tu hésites.",
                    onNext: save) {
            ArtImage(name: "ill_phone", zoom: glow ? 1.08 : 1, anchor: UnitPoint(x: 0.5, y: 0.45))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .enter(2)

            VStack(spacing: 0) {
                Text(hoursLabel)
                    .font(.figtree(52, .bold)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("par jour").font(.aBody).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .enter(3)

            VStack(spacing: 2) {
                Slider(value: $hours, in: 1...10, step: 0.5)
                    .tint(Palette.blue)
                    .accessibilityLabel("Heures par jour sur ton téléphone")
                HStack {
                    Text("1 h"); Spacer(); Text("5 h"); Spacer(); Text("10 h")
                }
                .font(.aCaption).foregroundStyle(Palette.muted)
            }
            .enter(4)
        }
        .onAppear {
            hours = user.profile.phoneHours
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { glow = true }
        }
        .onChange(of: hours) { _, _ in Haptics.selection() }
    }

    private func save() {
        user.profile.phoneHours = hours
        onNext()
    }
}

/// "4 h" ou "4 h 30".
func formatHours(_ hours: Double) -> String {
    let whole = Int(hours)
    return hours == Double(whole) ? "\(whole) h" : "\(whole) h 30"
}
