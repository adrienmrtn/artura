import SwiftUI

/// S'entraîner : une série de questions qui mélange les quatre types de jeux.
struct TrainingGame: View {
    @EnvironmentObject private var content: ContentStore
    let onFinish: (Int, Int) -> Void

    struct Choice: Identifiable {
        let id: String
        let title: String
        var subtitle: String? = nil
        var colors: [Color] = []
        var thumb: String? = nil
    }

    struct Round: Identifiable {
        let id = UUID()
        let kind: String
        let prompt: String
        var image: String? = nil
        var zoom: CGFloat = 1
        var anchor: UnitPoint = .center
        var statement: String? = nil
        let choices: [Choice]
        let correct: String
        let explanation: String
    }

    @State private var rounds: [Round] = []
    @State private var index = 0
    @State private var picked: String?
    @State private var score = 0

    private var round: Round? { rounds.indices.contains(index) ? rounds[index] : nil }
    private var isLast: Bool { index >= rounds.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let round {
                HStack {
                    TagPill(text: "\(round.kind) · \(index + 1) sur \(rounds.count)")
                    Spacer()
                    Text("\(score) point\(score > 1 ? "s" : "")")
                        .font(.figtree(14, .semibold)).foregroundStyle(Palette.muted)
                }
                Text(round.prompt).font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let image = round.image {
                    ArtImage(name: image, zoom: picked == nil ? round.zoom : 1, anchor: round.anchor)
                        .frame(height: round.statement == nil ? 230 : 170)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .animation(.easeOut(duration: 0.3), value: picked)
                }
                if let statement = round.statement {
                    Text(statement)
                        .font(.figtree(20, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    ForEach(round.choices) { choice in
                        choiceButton(choice, round: round)
                    }
                }

                if picked != nil {
                    Text(round.explanation)
                        .font(.aSmall).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(picked == round.correct ? Palette.greenSoft : Palette.redSoft))
                        .transition(.opacity)
                }

                Spacer(minLength: 0)

                if picked != nil {
                    Button(isLast ? "Voir mon score" : "Suivant") { advance() }
                        .buttonStyle(.primary)
                        .transition(.opacity)
                }
            }
        }
        .id(index)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if rounds.isEmpty { rounds = buildRounds() }
        }
    }

    private func choiceButton(_ choice: Choice, round: Round) -> some View {
        let answered = picked != nil
        let isAnswer = choice.id == round.correct
        let isPicked = choice.id == picked
        let fill: Color = answered && isAnswer ? Palette.greenSoft : (answered && isPicked ? Palette.redSoft : Palette.card)
        let border: Color = answered && isAnswer ? Palette.green : (answered && isPicked ? Palette.red : .clear)
        return Button {
            pick(choice, round: round)
        } label: {
            HStack(spacing: 12) {
                if let thumb = choice.thumb {
                    ArtImage(name: thumb)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if choice.colors.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(choice.title).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        if let subtitle = choice.subtitle {
                            Text(subtitle).font(.figtree(12)).foregroundStyle(Palette.muted)
                        }
                    }
                    Spacer(minLength: 8)
                } else {
                    ForEach(Array(choice.colors.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 10).fill(color).frame(height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.08), lineWidth: 1))
                    }
                }
                if answered && isAnswer { CheckBadge(color: Palette.green, size: 24) }
            }
            .padding(.horizontal, choice.thumb == nil ? 16 : 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
        .accessibilityLabel(choice.colors.isEmpty ? choice.title : "Palette")
    }

    private func pick(_ choice: Choice, round: Round) {
        guard picked == nil else { return }
        withAnimation(.easeOut(duration: 0.15)) { picked = choice.id }
        if choice.id == round.correct {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func advance() {
        Haptics.tap()
        if isLast {
            onFinish(score, rounds.count)
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                picked = nil
                index += 1
            }
        }
    }

    // MARK: Construction des questions

    private func buildRounds() -> [Round] {
        let arts = content.artworks
        guard arts.count >= 4 else { return [] }
        let kinds = (["zoom", "palette", "fact", "older"] + ["zoom", "palette", "fact", "older"]).shuffled()
        var facts = content.allFacts.shuffled()
        var result: [Round] = []

        for kind in kinds {
            guard let art = arts.randomElement() else { continue }
            let others = arts.filter { $0.id != art.id }.shuffled()
            switch kind {
            case "zoom":
                let options = (Array(others.prefix(3)) + [art]).shuffled()
                result.append(Round(
                    kind: "Zoom mystère", prompt: "De quelle œuvre vient ce détail ?",
                    image: art.image, zoom: 4, anchor: art.focusPoint,
                    choices: options.map { Choice(id: $0.id, title: $0.title, subtitle: $0.artist) },
                    correct: art.id, explanation: "\(art.title), \(art.artist)."
                ))
            case "palette":
                let options = (Array(others.prefix(2)) + [art]).shuffled()
                result.append(Round(
                    kind: "Palette", prompt: "Quelle palette est celle de ce tableau ?",
                    image: art.image,
                    choices: options.map { Choice(id: $0.id, title: $0.title, colors: $0.paletteColors) },
                    correct: art.id, explanation: "Ce sont les couleurs dominantes de « \(art.title) »."
                ))
            case "fact":
                guard let item = facts.popLast() else { continue }
                result.append(Round(
                    kind: "Vrai ou faux", prompt: "Vrai ou faux ?",
                    image: item.artwork.image, statement: item.fact.text,
                    choices: [Choice(id: "vrai", title: "Vrai"), Choice(id: "faux", title: "Faux")],
                    correct: item.fact.isTrue ? "vrai" : "faux", explanation: item.fact.explanation
                ))
            default:
                guard let other = others.first(where: { $0.year != art.year }) else { continue }
                let pair = [art, other].shuffled()
                let older = art.year < other.year ? art : other
                result.append(Round(
                    kind: "Chronologie", prompt: "Laquelle est la plus ancienne ?",
                    choices: pair.map { Choice(id: $0.id, title: $0.title, subtitle: $0.artist, thumb: $0.image) },
                    correct: older.id,
                    explanation: "\(pair[0].title) : \(pair[0].yearLabel). \(pair[1].title) : \(pair[1].yearLabel)."
                ))
            }
        }
        return result
    }
}
