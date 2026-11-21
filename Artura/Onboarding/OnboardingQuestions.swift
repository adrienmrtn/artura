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
                .font(.figtree(22, .semibold))
                .foregroundStyle(Palette.ink)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { if !trimmed.isEmpty { save() } }
                .padding(.horizontal, 18)
                .frame(height: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(focused ? Palette.blue : .clear, lineWidth: 2))
                .animation(.snappy, value: focused)
                .appearUp(0.2)
        }
        .onAppear {
            name = user.profile.firstName ?? ""
            // Le clavier monte une fois l'écran posé.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
    }

    private func save() {
        user.profile.firstName = trimmed
        focused = false
        onNext()
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
                    OptionRow(title: option.title, subtitle: option.subtitle, selected: selection == option.title) {
                        selection = option.title
                    }
                    .appearUp(0.16 * Double(i + 1))
                }
            }
        }
    }
}

// MARK: Pourquoi Artura

struct WhyScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    var body: some View {
        ChoiceScreen(title: "Pourquoi es-tu sur Artura ?",
                     subtitle: "Choisis ce qui te ressemble le plus.",
                     options: [
                        ChoiceOption(title: "Apprendre l'art"),
                        ChoiceOption(title: "Nourrir mon intelligence"),
                        ChoiceOption(title: "Avoir de nouvelles choses à raconter"),
                        ChoiceOption(title: "Préparer un examen"),
                        ChoiceOption(title: "Pour le plaisir")
                     ],
                     selection: $user.profile.goal, onNext: onNext)
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
