import SwiftUI

/// End-of-lesson quiz: one question at a time, with instant feedback.
struct QuizView: View {
    let artwork: Artwork
    let onBack: () -> Void
    /// Called at the end with the number of correct answers.
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var score = 0
    @State private var shake: CGFloat = 0

    private var question: QuizQuestion { artwork.quiz[index] }
    private var isLast: Bool { index >= artwork.quiz.count - 1 }
    private var isCorrect: Bool { selected == question.answer }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.pressable)
                .padding(.leading, -12)
                ProgressTrack(value: Double(index + (selected == nil ? 0 : 1)) / Double(artwork.quiz.count))
            }

            VStack(alignment: .leading, spacing: 8) {
                TagPill(text: "Question \(index + 1) of \(artwork.quiz.count)")
                Text(question.question)
                    .font(.aTitleSmall)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id("q\(index)")
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            ArtImage(name: artwork.image)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { i, option in
                    optionButton(i, option)
                }
            }
            .offset(x: shake)
            .id("o\(index)")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            if selected != nil {
                feedback.transition(.move(edge: .bottom))
            }
        }
    }

    private func optionButton(_ i: Int, _ option: String) -> some View {
        let answered = selected != nil
        let isAnswer = i == question.answer
        let isPicked = i == selected
        let border: Color = answered && isAnswer ? Palette.green : (answered && isPicked ? Palette.red : .clear)
        let fill: Color = answered && isAnswer ? Palette.greenSoft : (answered && isPicked ? Palette.redSoft : Palette.card)
        return Button {
            pick(i)
        } label: {
            HStack {
                Text(option)
                    .font(.figtree(16, answered && (isAnswer || isPicked) ? .semibold : .medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if answered && isAnswer {
                    CheckBadge(color: Palette.green).transition(.scale)
                } else if answered && isPicked {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.red))
                        .transition(.scale)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .disabled(answered)
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isCorrect ? "Good eye!" : "Not quite")
                    .font(.figtree(17, .semibold))
                Text(question.explanation)
                    .font(.aSmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Palette.ink)
            Button(isLast ? "Finish quiz" : "Next question") {
                advance()
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ArcTopShape().fill(Palette.blueSoft).ignoresSafeArea(edges: .bottom))
    }

    private func pick(_ i: Int) {
        guard selected == nil else { return }
        withAnimation(.snappy) { selected = i }
        // The feedback panel slides in: a second, duller haptic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Haptics.rigid() }
        if i == question.answer {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { shake = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.snappy) { shake = 0 }
            }
        }
    }

    private func advance() {
        Haptics.soft()
        if isLast {
            onFinish(score)
        } else {
            withAnimation(.gentle) {
                selected = nil
                index += 1
            }
        }
    }
}
