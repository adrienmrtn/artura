import SwiftUI

// MARK: Your first name

struct NameScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        OnbScaffold(title: L("And you, what's your name?"),
                    spoken: true,
                    ctaEnabled: !trimmed.isEmpty, onNext: save) {
            TextField(L("Your first name"), text: $name)
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
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(focused ? Palette.blue : .clear, lineWidth: 2))
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
            return L("Nice to meet you, %@! You are…", name)
        }
        return L("You are…")
    }

    var body: some View {
        OnbScaffold(title: title,
                    subtitle: L("So I can address you the right way."),
                    spoken: true,
                    ctaEnabled: user.profile.gender != nil, onNext: onNext) {
            HStack(spacing: 12) {
                portrait("ill_av1", L("A woman"), "femme")
                portrait("ill_av2", L("A man"), "homme")
            }
            .enter(2)
            VStack(spacing: 10) {
                ChoiceRow(title: L("Other"), selected: user.profile.gender == "autre") {
                    user.profile.gender = "autre"
                }
                ChoiceRow(title: L("I'd rather not say"), selected: user.profile.gender == "na") {
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
                    .foregroundStyle(Palette.ink)
            }
            .padding(.bottom, 14)
            .background(selected ? Palette.mistLight : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                if selected { CheckBadge().padding(8).transition(.scale.combined(with: .opacity)) }
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

    // `title` is the stored value (English); `label` is what is shown.
    private let options: [(title: String, label: String, image: String)] = [
        ("Learn about art", L("Learn about art"), "ill_goal_art"),
        ("Become more cultured", L("Become more cultured"), "ill_goal_culture"),
        ("Have new things to talk about", L("Have new things to talk about"), "ill_goal_talk"),
        ("Prepare for an exam", L("Prepare for an exam"), "ill_goal_exam"),
        ("Just for fun", L("Just for fun"), "ill_goal_fun")
    ]

    private var chosen: [String] { user.profile.goals ?? [] }

    var body: some View {
        OnbScaffold(title: L("What brings you here?"),
                    subtitle: L("Choose as many as you like."),
                    spoken: true,
                    ctaEnabled: !chosen.isEmpty, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    ChoiceRow(title: option.label, image: option.image,
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
        // The first motivation remains the "goal" recalled in the program.
        user.profile.goal = goals.first
    }
}

// MARK: Your arts

struct ArtsScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private let arts: [(id: String, title: String, image: String, soon: Bool)] = [
        ("peinture", L("Painting"), "ill_palette", false),
        ("sculpture", L("Sculpture"), "ill_sculpture", true),
        ("architecture", L("Architecture"), "ill_musee", true),
        ("photographie", L("Photography"), "ill_photo", true)
    ]

    var body: some View {
        OnbScaffold(title: L("Any art forms you'd like to explore?"),
                    subtitle: L("Painting is ready. The others are on their way."),
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
                                        // White pill over the artwork in both appearances, so the text stays dark.
                                        Text(L("Soon"))
                                            .font(.figtree(11, .semibold))
                                            .foregroundStyle(Color(hex: 0x2D2C2B))
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
                        .background(selected ? Palette.mistLight : Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
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
    /// Stored value (English).
    let title: String
    /// Text shown, when it differs from the stored value.
    var label: String? = nil
    var subtitle: String? = nil
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
                    ChoiceRow(title: option.label ?? option.title, subtitle: option.subtitle, selected: selection == option.title) {
                        selection = option.title
                    }
                    .enter(Double(i) + 2)
                }
            }
        }
    }
}

// MARK: Artworks you can't name

struct RecognizeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: L("Do you often see artworks you can't name?"),
                     subtitle: L("In a movie, on a poster, at a friend's place."),
                     options: [
                        ChoiceOption(title: "All the time", label: L("All the time")),
                        ChoiceOption(title: "Sometimes", label: L("Sometimes")),
                        ChoiceOption(title: "Rarely", label: L("Rarely"))
                     ],
                     selection: $user.profile.unknownArt, onNext: onNext)
    }
}

// MARK: Your knowledge

struct KnowledgeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    // The option title is also the stored level (shown later on the profile).
    var body: some View {
        ChoiceScreen(title: L("How well do you know art history?"),
                     subtitle: L("So I know where to start."),
                     options: [
                        ChoiceOption(title: "Beginner", label: L("Beginner"), subtitle: L("Starting from scratch, and that's perfectly fine.")),
                        ChoiceOption(title: "Enthusiast", label: L("Enthusiast"), subtitle: L("I know a few artists and movements.")),
                        ChoiceOption(title: "Connoisseur", label: L("Connoisseur"), subtitle: L("I can tell a Monet from a Manet."))
                     ],
                     selection: $user.profile.level, onNext: onNext)
    }
}

// MARK: The museum

struct MuseumScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: L("Do you go to museums often?"),
                     options: [
                        ChoiceOption(title: "Almost never", label: L("Almost never")),
                        ChoiceOption(title: "Once or twice a year", label: L("Once or twice a year")),
                        ChoiceOption(title: "A few times a year", label: L("A few times a year")),
                        ChoiceOption(title: "Every chance I get", label: L("Every chance I get"))
                     ],
                     selection: $user.profile.museumHabit, onNext: onNext)
    }
}

// MARK: Time spent on your phone

struct PhoneTimeScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    /// Slider position, continuous. The kept value is rounded to the half hour.
    @State private var raw: Double = 4
    @State private var glow = false

    private var hours: Double { (raw * 2).rounded() / 2 }

    var body: some View {
        OnbScaffold(title: L("How much time do you spend on your phone each day?"),
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
                Text(L("per day")).font(.aBody).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .enter(3)

            VStack(spacing: 2) {
                Slider(value: $raw, in: 1...10)
                    .tint(Palette.blue)
                    .accessibilityLabel(L("Hours per day on your phone"))
                    .accessibilityValue(formatHours(hours))
                HStack {
                    Text(formatHours(1)); Spacer(); Text(formatHours(5)); Spacer(); Text(formatHours(10))
                }
                .font(.aCaption).foregroundStyle(Palette.muted)
            }
            .enter(4)
        }
        .onAppear {
            raw = user.profile.phoneHours
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { glow = true }
        }
        // One tick per half hour crossed, not on every finger move.
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
    return hours == Double(whole) ? L("%@h", "\(whole)") : L("%@h 30", "\(whole)")
}
