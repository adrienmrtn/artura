import SwiftUI

// MARK: Your first name

struct NameScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        OnbScaffold(title: "What's your name?",
                    subtitle: "So we know who we're talking to.",
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
            // The keyboard comes up once the screen has settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { focused = true }
        }
    }

    private func save() {
        user.profile.firstName = trimmed
        focused = false
        onNext()
    }
}

// MARK: You are…

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
                    subtitle: "So we can address you the right way.",
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
                ChoiceRow(title: "Prefer not to say", selected: user.profile.gender == "na") {
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

// MARK: What brings you here? (multiple answers)

struct MotivationScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private let options: [(title: String, symbol: String)] = [
        ("Learn about art", "paintpalette.fill"),
        ("Feed my mind", "brain.head.profile"),
        ("Have new stories to tell", "bubble.left.and.bubble.right.fill"),
        ("Prepare for an exam", "graduationcap.fill"),
        ("Just for fun", "sparkles")
    ]

    private var chosen: [String] { user.profile.goals ?? [] }

    var body: some View {
        OnbScaffold(title: "What brings you here?",
                    subtitle: "Pick as many as you like.",
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
        // The first motivation stays the "goal" shown in the plan.
        user.profile.goal = goals.first
    }
}

// MARK: Your arts

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
        OnbScaffold(title: "Any arts you especially want to explore?",
                    subtitle: "As many as you like. Painting is ready, the rest are coming.",
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

// MARK: Single-choice question (shared template)

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

// MARK: The artworks you can't name

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

// MARK: What you know

struct KnowledgeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    // The option title is also the stored level (shown later on the profile).
    var body: some View {
        ChoiceScreen(title: "How well do you know art history?",
                     subtitle: "This sets your starting point. You can change it later.",
                     options: [
                        ChoiceOption(title: "Beginner", subtitle: "Starting from scratch, and that's great."),
                        ChoiceOption(title: "Enthusiast", subtitle: "I know a few artists and movements."),
                        ChoiceOption(title: "Connoisseur", subtitle: "I can tell a Monet from a Manet.")
                     ],
                     selection: $user.profile.level, onNext: onNext)
    }
}

// MARK: Museums

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

// MARK: Time spent on your phone

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    @State private var hours: Double = 4
    @State private var glow = false

    private var hoursLabel: String { formatHours(hours) }

    var body: some View {
        OnbScaffold(title: "How much time a day on your phone?",
                    subtitle: "Check Settings › Screen Time if you're not sure.",
                    onNext: save) {
            ArtImage(name: "ill_phone", zoom: glow ? 1.08 : 1, anchor: UnitPoint(x: 0.5, y: 0.45))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .enter(2)

            VStack(spacing: 0) {
                Text(hoursLabel)
                    .font(.figtree(52, .bold)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("a day").font(.aBody).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .enter(3)

            VStack(spacing: 2) {
                Slider(value: $hours, in: 1...10, step: 0.5)
                    .tint(Palette.blue)
                    .accessibilityLabel("Hours a day on your phone")
                HStack {
                    Text("1h"); Spacer(); Text("5h"); Spacer(); Text("10h")
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

/// "4h" or "4h 30".
func formatHours(_ hours: Double) -> String {
    let whole = Int(hours)
    return hours == Double(whole) ? "\(whole)h" : "\(whole)h 30"
}
