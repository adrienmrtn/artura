import SwiftUI

/// Palette: pick, out of three palettes, the one from the painting shown.
struct PaletteGame: View {
    @EnvironmentObject private var content: ContentStore
    let onFinish: (Int, Int) -> Void

    @State private var rounds: [Artwork] = []
    @State private var options: [Artwork] = []
    @State private var index = 0
    @State private var selected: String?
    @State private var score = 0

    private var current: Artwork? { rounds.indices.contains(index) ? rounds[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let current {
                HStack {
                    TagPill(text: L("Round %@ of %@", "\(index + 1)", "\(rounds.count)"))
                    Spacer()
                    Text(score == 1 ? L("1 point") : L("%@ points", "\(score)"))
                        .font(.figtree(14, .semibold)).foregroundStyle(Palette.muted)
                        .contentTransition(.numericText())
                }
                Text(L("Which palette matches this painting?")).font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                ArtImage(name: current.image)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .id(current.id)
                    .transition(.opacity)

                Text("\(current.title) · \(current.artist)").font(.aCaption).foregroundStyle(Palette.muted)

                VStack(spacing: 10) {
                    ForEach(options) { option in
                        paletteButton(option, correct: current)
                    }
                }

                Spacer(minLength: 0)

                if selected != nil {
                    Button(index >= rounds.count - 1 ? L("See my score") : L("Next")) { advance() }
                        .buttonStyle(.primary)
                        .transition(.opacity.combined(with: .offset(y: 16)))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: start)
    }

    private func paletteButton(_ option: Artwork, correct: Artwork) -> some View {
        let answered = selected != nil
        let isAnswer = option.id == correct.id
        let isPicked = option.id == selected
        let border: Color = answered && isAnswer ? Palette.green : (answered && isPicked ? Palette.red : .clear)
        return Button {
            pick(option, correct: correct)
        } label: {
            HStack(spacing: 8) {
                ForEach(Array(option.paletteColors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color)
                        .frame(height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.08), lineWidth: 1))
                }
                if answered && isAnswer {
                    CheckBadge(color: Palette.green, size: 24).transition(.scale)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 3))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
        .accessibilityLabel(answered && isAnswer ? L("Correct palette") : L("Palette"))
    }

    private func start() {
        rounds = Array(content.artworks.filter { !$0.palette.isEmpty }.shuffled().prefix(5))
        index = 0
        score = 0
        prepare()
    }

    private func prepare() {
        guard let current else { return }
        let others = content.artworks.filter { $0.id != current.id && !$0.palette.isEmpty }.shuffled().prefix(2)
        options = (Array(others) + [current]).shuffled()
        selected = nil
    }

    private func pick(_ option: Artwork, correct: Artwork) {
        guard selected == nil else { return }
        withAnimation(.snappy) { selected = option.id }
        if option.id == correct.id {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func advance() {
        if index >= rounds.count - 1 {
            onFinish(score, rounds.count)
        } else {
            Haptics.tap()
            withAnimation(.gentle) {
                index += 1
                prepare()
            }
        }
    }
}
