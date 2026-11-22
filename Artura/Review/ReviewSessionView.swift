import SwiftUI

/// Plays a deck of questions one by one, then shows the score.
struct ReviewSessionView: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.dismiss) private var dismiss
    let deck: ReviewDeck

    @State private var index = 0
    @State private var picked: String?
    @State private var score = 0
    @State private var finished = false

    private var card: ReviewCard? { deck.cards.indices.contains(index) ? deck.cards[index] : nil }
    private var isLast: Bool { index >= deck.cards.count - 1 }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if finished || deck.cards.isEmpty {
                ResultView(
                    title: score == deck.cards.count ? "Perfect score!" : (score * 2 >= deck.cards.count ? "Nicely done" : "Keep at it"),
                    detail: "\(score) of \(deck.cards.count) correct",
                    celebrate: score * 2 >= deck.cards.count,
                    onDone: { dismiss() }
                )
                .transition(.opacity)
            } else if let card {
                VStack(spacing: 0) {
                    header
                    question(card)
                        .id(index)
                        .transition(.opacity)
                }
            }
        }
        .onAppear { Haptics.soft() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.card))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Quit the session")
            ProgressTrack(value: Double(index + (picked == nil ? 0 : 1)) / Double(max(1, deck.cards.count)))
            Text("\(index + 1) / \(deck.cards.count)")
                .font(.figtree(14, .medium))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func question(_ card: ReviewCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TagPill(text: card.kind)
                    Text(card.prompt)
                        .font(.aTitleSmall)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let image = card.image {
                        ArtImage(name: image, anchor: card.anchor)
                            .frame(height: card.statement == nil ? 200 : 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    if let statement = card.statement {
                        Text(statement)
                            .font(.figtree(19, .semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 8) {
                        ForEach(card.choices) { choice in
                            choiceButton(choice, card: card)
                        }
                    }

                    if picked != nil {
                        Text(card.explanation)
                            .font(.aSmall)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(picked == card.correct ? Palette.greenSoft : Palette.redSoft))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            Button(isLast ? "See my score" : "Next") { advance() }
                .buttonStyle(.primary)
                .disabled(picked == nil)
                .opacity(picked == nil ? 0.4 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    private func choiceButton(_ choice: ReviewCard.Choice, card: ReviewCard) -> some View {
        let answered = picked != nil
        let isAnswer = choice.id == card.correct
        let isPicked = choice.id == picked
        let fill: Color = answered && isAnswer ? Palette.greenSoft : (answered && isPicked ? Palette.redSoft : Color.white)
        let border: Color = answered && isAnswer ? Palette.green : (answered && isPicked ? Palette.red : Palette.line)
        return Button {
            pick(choice, card: card)
        } label: {
            HStack(spacing: 12) {
                Text(choice.title)
                    .font(.figtree(15, .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if answered && isAnswer { CheckBadge(color: Palette.green, size: 24) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: answered && (isAnswer || isPicked) ? 2 : 1))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
    }

    private func pick(_ choice: ReviewCard.Choice, card: ReviewCard) {
        guard picked == nil else { return }
        withAnimation(.easeOut(duration: 0.15)) { picked = choice.id }
        if choice.id == card.correct {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func advance() {
        Haptics.tap()
        if isLast {
            // A finished session keeps the streak alive; the daily review is marked done.
            if deck.daily { user.completeReview() } else { user.markPlayedToday() }
            withAnimation(.gentle) { finished = true }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                picked = nil
                index += 1
            }
        }
    }
}
