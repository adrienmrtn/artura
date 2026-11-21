import SwiftUI

// MARK: Welcome

struct WelcomeScreen: View {
    let onNext: () -> Void
    let onLogin: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_hero", imageHeight: 460, cta: "Get started", onNext: onNext,
                     secondaryTitle: "I already have an account", onSecondary: onLogin) {
            Text("ARTURA")
                .font(.figtree(13, .bold))
                .tracking(3)
                .foregroundStyle(Palette.blue)
                .enter(0)
            Text("Finally, learn art")
                .font(.figtree(36, .bold))
                .foregroundStyle(Palette.ink)
                .enter(1)
            Text("5 minutes a day, with sessions made for you.")
                .font(.figtree(17))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .enter(2.5)
        }
    }
}

// MARK: One masterpiece a day (wall of paintings)

struct DailyScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FloatingWall()
                .enter()

            VStack(spacing: 12) {
                Text("One masterpiece a day")
                    .font(.figtree(34, .bold))
                    .foregroundStyle(Palette.ink)
                    .enter(2)
                Text("Get cultured without even noticing.")
                    .font(.figtree(17))
                    .foregroundStyle(Palette.muted)
                    .enter(3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 26)

            HStack(spacing: 12) {
                proof(value: SocialProof.learners, label: "people already learning") {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                }
                proof(value: SocialProof.rating, label: "average rating") {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.yellow)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .enter(5)

            Spacer(minLength: 16)

            Button("Continue") { onNext() }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
    }

    private func proof<Mark: View>(value: String, label: String, @ViewBuilder mark: () -> Mark) -> some View {
        VStack(spacing: 4) {
            mark().frame(height: 16)
            Text(value)
                .font(.figtree(26, .bold))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.aCaption)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: A museum in your pocket

struct PocketMuseumScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_musee",
                      title: "Artura is a museum in your pocket.",
                      subtitle: "Artura was made for art lovers.",
                      onNext: onNext)
    }
}

// MARK: At the museum too

struct PhotoScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_photo",
                      tag: "And at the museum?",
                      title: "Snap a photo of any artwork and ask what it means.",
                      subtitle: "Then save the ones you want to remember to your collection.",
                      onNext: onNext)
    }
}

// MARK: Quotes: why Artura

struct Quote: Identifiable {
    let image: String
    let text: String
    let author: String
    let role: String
    var id: String { author }

    // Quotes to be verified (source and translation) before release.
    static let all: [Quote] = [
        Quote(image: "portrait_klee", text: "Art does not reproduce the visible; it makes visible.", author: "Paul Klee", role: "Painter"),
        Quote(image: "portrait_nietzsche", text: "We have art so that we shall not die of the truth.", author: "Friedrich Nietzsche", role: "Philosopher"),
        Quote(image: "portrait_proust", text: "Through art alone are we able to emerge from ourselves.", author: "Marcel Proust", role: "Writer")
    ]
}

struct QuotesScreen: View {
    let onNext: () -> Void
    @State private var shown = 0

    private let quotes = Quote.all

    var body: some View {
        OnbScaffold(title: "This is why we created Artura",
                    subtitle: "Art is timeless. They said it long before us.",
                    onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                    HStack(alignment: .top, spacing: 14) {
                        ArtImage(name: quote.image, anchor: .top)
                            .saturation(0)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("“\(quote.text)”")
                                .font(.serif(18, .medium))
                                .italic()
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(quote.author) · \(quote.role)")
                                .font(.aCaption)
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown ? 0 : 18)
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            // The quotes come in one by one, without blocking anything.
            for i in 1...quotes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i - 1) * 0.6) {
                    withAnimation(.settle) { shown = max(shown, i) }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: The Mona Lisa speaks

struct QuestionsIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotScaffold(title: "A few questions to get to know you.",
                       subtitle: "Less than a minute, for a program built around you.",
                       cta: "Let's go", onNext: onNext)
    }
}

struct TestIntroScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "Great, \(name). Let's see what you already know."
        }
        return "Great. Let's see what you already know."
    }

    var body: some View {
        MascotScaffold(title: title,
                       subtitle: "Seven paintings, from the most famous to the most obscure.",
                       cta: user.agree("I'm ready", "I'm ready"), onNext: onNext)
    }
}

// MARK: Understand, not just learn (typewriter text)

struct UnderstandScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            MascotBubble(mascotSize: 150) {
                TypewriterText(text: "With Artura, you don't just learn names. You understand the story behind each painting, and what it means.")
            }
            .enter()

            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                Text("Your first guided tour · 2 min")
                    .font(.figtree(14, .semibold))
            }
            .foregroundStyle(Palette.blue)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Palette.sand))
            .padding(.top, 22)
            .enter(4)

            Spacer(minLength: 16)
            Spacer(minLength: 0)

            Button("Start the tour") { onNext() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}
