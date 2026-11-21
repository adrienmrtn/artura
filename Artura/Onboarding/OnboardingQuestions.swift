import SwiftUI

// MARK: Ton prénom

struct NameScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        OnbScaffold(title: "And you, what's your name?",
                    spoken: true,
                    ctaEnabled: !trimmed.isEmpty, onNext: save) {
            TextField("Your first name", text: $name)
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
                .background(RoundedRectangle(cornerRadius: 18).fill(.white))
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
            return "Nice to meet you, \(name)! You are…"
        }
        return "You are…"
    }

    var body: some View {
        OnbScaffold(title: title,
                    subtitle: "So I can address you the right way.",
                    spoken: true,
                    ctaEnabled: user.profile.gender != nil, onNext: onNext) {
            HStack(spacing: 12) {
                portrait("ill_av1", "A woman", "femme")
                portrait("ill_av2", "A man", "homme")
            }
            .enter(2)
            VStack(spacing: 10) {
                ChoiceRow(title: "Other", selected: user.profile.gender == "autre") {
                    user.profile.gender = "autre"
                }
                ChoiceRow(title: "I'd rather not say", selected: user.profile.gender == "na") {
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
                ArtImage(name: image).frame(height: 132)
                Text(label)
                    .font(.figtree(17, .semibold))
                    .foregroundStyle(selected ? .white : Palette.ink)
            }
            .padding(.bottom, 14)
            .background(selected ? Palette.blue : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Palette.blue : Palette.line, lineWidth: selected ? 3 : 1)
            )
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
        ("Learn about art", "paintpalette.fill"),
        ("Become more cultured", "brain.head.profile"),
        ("Have new things to talk about", "bubble.left.and.bubble.right.fill"),
        ("Prepare for an exam", "graduationcap.fill"),
        ("Just for fun", "sparkles")
    ]

    private var chosen: [String] { user.profile.goals ?? [] }

    var body: some View {
        OnbScaffold(title: "What brings you here?",
                    subtitle: "Choose as many as you like.",
                    spoken: true,
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
        ("peinture", "Painting", "ill_palette", false),
        ("sculpture", "Sculpture", "ill_sculpture", true),
        ("architecture", "Architecture", "ill_musee", true),
        ("photographie", "Photography", "ill_photo", true)
    ]

    var body: some View {
        OnbScaffold(title: "Any art forms you'd like to explore?",
                    subtitle: "Painting is ready. The others are on their way.",
                    spoken: true,
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
                                .frame(height: 96)
                                .overlay(alignment: .topLeading) {
                                    if art.soon {
                                        Text("Soon")
                                            .font(.figtree(11, .semibold))
                                            .foregroundStyle(Palette.ink)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(.white))
                                            .padding(8)
                                    }
                                }
                            Text(art.title)
                                .font(.bodyStrong)
                                .foregroundStyle(selected ? .white : Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                        .background(selected ? Palette.blue : Color.white)
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
    /// Valeur enregistrée, si elle diffère du texte affiché.
    var value: String? = nil

    var stored: String { value ?? title }
}

struct ChoiceScreen: View {
    let title: String
    var subtitle: String? = nil
    let options: [ChoiceOption]
    @Binding var selection: String?
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(title: title, subtitle: subtitle, spoken: true, ctaEnabled: selection != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    ChoiceRow(title: option.title, subtitle: option.subtitle, selected: selection == option.stored) {
                        selection = option.stored
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
        ChoiceScreen(title: "Do you often see artworks you can't name?",
                     subtitle: "In a movie, on a poster, at a friend's place.",
                     options: [
                        ChoiceOption(title: "All the time"),
                        ChoiceOption(title: "Sometimes"),
                        ChoiceOption(title: "Rarely")
                     ],
                     selection: $user.profile.unknownArt, onNext: onNext)
    }
}

// MARK: Tes connaissances

struct KnowledgeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    // Le niveau enregistré reste en français : il est affiché tel quel sur le profil de l'appli.
    var body: some View {
        ChoiceScreen(title: "How well do you know art history?",
                     subtitle: "So I know where to start.",
                     options: [
                        ChoiceOption(title: "Beginner", subtitle: "Starting from scratch, and that's perfectly fine.", value: "Débutant"),
                        ChoiceOption(title: "Enthusiast", subtitle: "I know a few artists and movements.", value: "Amateur"),
                        ChoiceOption(title: "Connoisseur", subtitle: "I can tell a Monet from a Manet.", value: "Connaisseur")
                     ],
                     selection: $user.profile.level, onNext: onNext)
    }
}

// MARK: Le musée

struct MuseumScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: "Do you go to museums often?",
                     options: [
                        ChoiceOption(title: "Almost never"),
                        ChoiceOption(title: "Once or twice a year"),
                        ChoiceOption(title: "A few times a year"),
                        ChoiceOption(title: "Every chance I get")
                     ],
                     selection: $user.profile.museumHabit, onNext: onNext)
    }
}

// MARK: Le temps passé sur ton téléphone

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    /// Position du curseur, en continu. La valeur retenue est arrondie à la demi-heure.
    @State private var raw: Double = 4
    @State private var glow = false

    private var hours: Double { (raw * 2).rounded() / 2 }

    var body: some View {
        OnbScaffold(title: "How much time do you spend on your phone each day?",
                    spoken: true, onNext: save) {
            ArtImage(name: "ill_phone", zoom: glow ? 1.08 : 1, anchor: UnitPoint(x: 0.5, y: 0.45))
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .enter(2)

            VStack(spacing: 0) {
                Text(formatHours(hours))
                    .font(.figtree(52, .bold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: hours))
                    .animation(.snappy, value: hours)
                Text("per day").font(.aBody).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .enter(3)

            VStack(spacing: 2) {
                Slider(value: $raw, in: 1...10)
                    .tint(Palette.blue)
                    .accessibilityLabel("Hours per day on your phone")
                    .accessibilityValue(formatHours(hours))
                HStack {
                    Text("1h"); Spacer(); Text("5h"); Spacer(); Text("10h")
                }
                .font(.aCaption).foregroundStyle(Palette.muted)
            }
            .enter(4)
        }
        .onAppear {
            raw = user.profile.phoneHours
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { glow = true }
        }
        // Un cran à chaque demi-heure franchie, pas à chaque mouvement du doigt.
        .onChange(of: hours) { _, _ in Haptics.selection() }
    }

    private func save() {
        user.profile.phoneHours = hours
        onNext()
    }
}

/// "4h" ou "4h 30".
func formatHours(_ hours: Double) -> String {
    let whole = Int(hours)
    return hours == Double(whole) ? "\(whole)h" : "\(whole)h 30"
}
