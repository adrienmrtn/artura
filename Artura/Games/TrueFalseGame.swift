import SwiftUI

/// Vrai ou faux : une carte à glisser à droite (vrai) ou à gauche (faux).
struct TrueFalseGame: View {
    @EnvironmentObject private var content: ContentStore
    let onFinish: (Int, Int) -> Void

    struct Card: Identifiable {
        let id = UUID()
        let fact: Fact
        let artwork: Artwork
    }

    @State private var deck: [Card] = []
    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var answer: Bool?
    @State private var score = 0

    private var card: Card? { deck.indices.contains(index) ? deck[index] : nil }
    private var isCorrect: Bool { answer != nil && answer == card?.fact.isTrue }

    var body: some View {
        VStack(spacing: 14) {
            if let card {
                HStack {
                    TagPill(text: "Carte \(index + 1) sur \(deck.count)")
                    Spacer()
                    Text("\(score) point\(score > 1 ? "s" : "")")
                        .font(.figtree(14, .semibold)).foregroundStyle(Palette.muted)
                        .contentTransition(.numericText())
                }

                ZStack {
                    if deck.indices.contains(index + 1) {
                        RoundedRectangle(cornerRadius: 24).fill(Palette.line)
                            .scaleEffect(0.94).offset(y: 14)
                    }
                    cardView(card)
                        .offset(x: drag.width, y: drag.height * 0.2)
                        .rotationEffect(.degrees(Double(drag.width) / 18))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard answer == nil else { return }
                                    drag = value.translation
                                }
                                .onEnded { value in
                                    guard answer == nil else { return }
                                    if value.translation.width > 90 {
                                        respond(true)
                                    } else if value.translation.width < -90 {
                                        respond(false)
                                    } else {
                                        withAnimation(.bouncy) { drag = .zero }
                                    }
                                }
                        )
                        .id(card.id)
                        .transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .opacity))
                }
                .frame(maxHeight: 430)

                Spacer(minLength: 0)

                if answer == nil {
                    HStack(spacing: 12) {
                        Button("Faux") { respond(false) }
                            .buttonStyle(PillButtonStyle(fill: Palette.redSoft, lip: Color(hex: 0xF2C9C5), foreground: Color(hex: 0x8C1D18)))
                        Button("Vrai") { respond(true) }
                            .buttonStyle(PillButtonStyle(fill: Palette.greenSoft, lip: Color(hex: 0xBFE6CD), foreground: Color(hex: 0x00663B)))
                    }
                    .transition(.opacity)
                } else {
                    Button(index >= deck.count - 1 ? "Voir mon score" : "Suivant") { advance() }
                        .buttonStyle(.primary)
                        .transition(.opacity.combined(with: .offset(y: 16)))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if deck.isEmpty {
                deck = content.allFacts.shuffled().prefix(8).map { Card(fact: $0.fact, artwork: $0.artwork) }
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtImage(name: card.artwork.image)
                .frame(height: 200)
                .overlay(alignment: .topLeading) { stamp("Vrai", Palette.green).opacity(stampOpacity(true)).padding(14) }
                .overlay(alignment: .topTrailing) { stamp("Faux", Palette.red).opacity(stampOpacity(false)).padding(14) }
            VStack(alignment: .leading, spacing: 10) {
                Text(card.artwork.title).font(.figtree(13, .semibold)).foregroundStyle(Palette.blueText)
                Text(card.fact.text)
                    .font(.figtree(20, .semibold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if answer != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCorrect ? "Bien vu !" : "Raté : c'était \(card.fact.isTrue ? "vrai" : "faux").")
                            .font(.bodyStrong).foregroundStyle(isCorrect ? Color(hex: 0x00663B) : Color(hex: 0x8C1D18))
                        Text(card.fact.explanation).font(.aSmall).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isCorrect ? Palette.greenSoft : Palette.redSoft))
                    .transition(.opacity.combined(with: .offset(y: 10)))
                } else {
                    Text("Glisse à droite pour vrai, à gauche pour faux.")
                        .font(.aCaption).foregroundStyle(Palette.muted)
                }
            }
            .padding(18)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.figtree(20, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(color))
    }

    private func stampOpacity(_ forTrue: Bool) -> Double {
        guard answer == nil else { return 0 }
        let amount = Double(drag.width) / 90
        return min(1, max(0, forTrue ? amount : -amount))
    }

    private func respond(_ value: Bool) {
        guard let card, answer == nil else { return }
        withAnimation(.bouncy) {
            answer = value
            drag = .zero
        }
        if value == card.fact.isTrue {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func advance() {
        if index >= deck.count - 1 {
            onFinish(score, deck.count)
        } else {
            Haptics.tap()
            withAnimation(.gentle) {
                answer = nil
                index += 1
            }
        }
    }
}
