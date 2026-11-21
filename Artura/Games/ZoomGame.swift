import SwiftUI

/// Zoom mystère : un détail très agrandi, quatre propositions. On peut dézoomer pour s'aider.
struct ZoomGame: View {
    @EnvironmentObject private var content: ContentStore
    let onFinish: (Int, Int) -> Void

    @State private var rounds: [Artwork] = []
    @State private var options: [Artwork] = []
    @State private var index = 0
    @State private var zoomStep = 0
    @State private var selected: String?
    @State private var score = 0

    private let zooms: [CGFloat] = [6, 3.5, 2]
    private var current: Artwork? { rounds.indices.contains(index) ? rounds[index] : nil }
    private var zoom: CGFloat { selected != nil ? 1 : zooms[min(zoomStep, zooms.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let current {
                HStack {
                    TagPill(text: "Manche \(index + 1) sur \(rounds.count)")
                    Spacer()
                    Text("\(score) point\(score > 1 ? "s" : "")")
                        .font(.figtree(14, .semibold)).foregroundStyle(Palette.muted)
                        .contentTransition(.numericText())
                }
                Text("De quelle œuvre vient ce détail ?").font(.aTitleSmall).foregroundStyle(Palette.ink)

                ArtImage(name: current.image, zoom: zoom, anchor: current.focusPoint)
                    .frame(height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: zoom)
                    .overlay(alignment: .bottomTrailing) {
                        if selected == nil && zoomStep < zooms.count - 1 {
                            Button {
                                Haptics.soft()
                                zoomStep += 1
                            } label: {
                                Label("Dézoomer", systemImage: "minus.magnifyingglass")
                                    .font(.figtree(14, .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 14)
                                    .frame(height: 44)
                                    .background(Capsule().fill(.white))
                            }
                            .buttonStyle(.pressable)
                            .padding(10)
                            .transition(.opacity)
                        }
                    }

                VStack(spacing: 8) {
                    ForEach(options) { option in
                        answerButton(option, correct: current)
                    }
                }

                Spacer(minLength: 0)

                if selected != nil {
                    Button(index >= rounds.count - 1 ? "Voir mon score" : "Suivant") { advance() }
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

    private func answerButton(_ option: Artwork, correct: Artwork) -> some View {
        let answered = selected != nil
        let isAnswer = option.id == correct.id
        let isPicked = option.id == selected
        let fill: Color = answered && isAnswer ? Palette.greenSoft : (answered && isPicked ? Palette.redSoft : Palette.card)
        let border: Color = answered && isAnswer ? Palette.green : (answered && isPicked ? Palette.red : .clear)
        return Button {
            pick(option, correct: correct)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(option.artist).font(.figtree(12)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                if answered && isAnswer { CheckBadge(color: Palette.green, size: 24).transition(.scale) }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
    }

    private func start() {
        rounds = Array(content.artworks.shuffled().prefix(5))
        index = 0
        score = 0
        prepare()
    }

    private func prepare() {
        guard let current else { return }
        let others = content.artworks.filter { $0.id != current.id }.shuffled().prefix(3)
        options = (Array(others) + [current]).shuffled()
        zoomStep = 0
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
            withAnimation(.gentle) {
                index += 1
                prepare()
            }
        }
    }
}
