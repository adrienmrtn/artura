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
            Text("Finally learn art")
                .font(.figtree(36, .bold))
                .foregroundStyle(Palette.ink)
                .enter(1)
            Text("5 minutes a day. Sessions tailored to you.")
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
                      subtitle: "Built for art lovers, and for everyone who wants to become one.",
                      onNext: onNext)
    }
}

// MARK: At the museum too

struct PhotoScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_photo",
                      tag: "At the museum?",
                      title: "Snap any artwork. Artura explains it.",
                      subtitle: "And save the ones you want to remember to your collection.",
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

    // Quotes to be checked (source and translation) before release.
    static let all: [Quote] = [
        Quote(image: "portrait_klee", text: "Art does not reproduce the visible; it makes visible.", author: "Paul Klee", role: "Painter"),
        Quote(image: "portrait_nietzsche", text: "We have art in order not to die of the truth.", author: "Friedrich Nietzsche", role: "Philosopher"),
        Quote(image: "portrait_proust", text: "Through art alone are we able to emerge from ourselves.", author: "Marcel Proust", role: "Writer")
    ]
}

struct QuotesScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    /// Number of quotes revealed so far: each tap brings the next one, then the screen moves on.
    @State private var shown = min(max(0, OnboardingDebug.int("onbQuotesShown")), Quote.all.count)

    private let quotes = Quote.all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)
            .padding(.leading, -12)
            .padding(.top, 8)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 8) {
                Text("This is why we built Artura")
                    .font(.aTitle)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Art is timeless. They said it long before us.")
                    .font(.aBody)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
            .enter()

            VStack(alignment: .leading, spacing: 28) {
                ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                    HStack(alignment: .top, spacing: 14) {
                        ArtImage(name: quote.image, anchor: .top)
                            .saturation(0)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("“\(quote.text)”")
                                .font(.serif(20, .medium))
                                .italic()
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(quote.author) · \(quote.role)")
                                .font(.aCaption)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                    }
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown ? 0 : 18)
                }
            }
            .padding(.top, 36)

            Spacer(minLength: 16)

            TapHint(light: true)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // The first quote comes by itself; the others wait for a tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if shown == 0 { reveal() }
            }
        }
    }

    private func advance() {
        if shown < quotes.count {
            reveal()
        } else {
            Haptics.tap()
            onNext()
        }
    }

    private func reveal() {
        withAnimation(.settle) { shown += 1 }
        Haptics.soft()
    }
}

/// "Tap to continue", at the bottom of screens that move on with a tap anywhere.
struct TapHint: View {
    /// White text, for dark screens.
    var light: Bool = false
    @State private var pulse = false

    var body: some View {
        Text("Tap to continue")
            .font(.figtree(15, .semibold))
            .foregroundStyle(light ? Color.white.opacity(0.7) : Palette.muted)
            .opacity(pulse ? 1 : 0.45)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

// MARK: The Mona Lisa speaks

/// "Hi, I'm Artura": the character introduces herself, right after the welcome screen.
struct HelloScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "Hi, I'm Artura. Every day, I'll show you one masterpiece and the story behind it."
        ], cta: "Hi Artura!", mascotSize: 190, onNext: onNext)
    }
}

struct QuestionsIntroScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "Let's get to know each other. A few quick questions, under a minute, to build your program."
        ], cta: "Let's go", onNext: onNext)
    }
}

struct TestIntroScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    private var line: String {
        let start: String
        if let name = user.profile.firstName, !name.isEmpty {
            start = "Great, \(name)."
        } else {
            start = "Great."
        }
        return "\(start) Let's see what you already know: seven paintings, from the most famous to the hardest."
    }

    var body: some View {
        MascotTalkScreen(lines: [line], cta: "I'm ready", onNext: onNext)
    }
}

// MARK: Before the guided tour: looking can be learned

struct LearnToLookScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_oeil",
                      tag: "Artura will help",
                      title: "Looking can be learned",
                      subtitle: "Nobody is born knowing how to read a painting. Every day, I show you where to rest your eyes: a detail, a color, a gesture.",
                      onNext: onNext)
    }
}

// MARK: The Chicago study

struct StudyScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_regard",
                      tag: "A study at the Art Institute of Chicago",
                      title: "26 seconds in front of a painting",
                      subtitle: "That's how long a visitor looks at a masterpiece, on average. Barely enough to read the label.",
                      onNext: onNext)
    }
}

// MARK: What you'll be able to do

struct AbilitiesScreen: View {
    let onNext: () -> Void

    private let abilities: [(image: String, title: String, text: String)] = [
        ("ill_oeil", "Look", "Spot what matters in a painting, even one you've never seen."),
        ("ill_galerie", "Understand", "Who painted it, when, and why it changed everything."),
        ("ill_goal_talk", "Talk about it", "Have something to say at the museum, or over dinner.")
    ]

    var body: some View {
        OnbScaffold(title: "Soon, you'll know how to",
                    subtitle: "A few minutes a day is all it takes.",
                    onNext: onNext) {
            VStack(spacing: 12) {
                ForEach(Array(abilities.enumerated()), id: \.offset) { i, ability in
                    HStack(spacing: 14) {
                        ArtImage(name: ability.image)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ability.title).font(.aHeading).foregroundStyle(Palette.ink)
                            Text(ability.text)
                                .font(.aSmall)
                                .foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card))
                    .enter(Double(i) * 1.5 + 2)
                }
            }
        }
    }
}

// MARK: Choose your first lesson

struct ChooseCourseScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onNext: () -> Void

    /// The paintings whose lesson is a full interactive tour.
    private var courses: [Artwork] {
        Array(content.artworks.filter { $0.lesson.contains { $0.isInteractive } }.prefix(4))
    }

    var body: some View {
        OnbScaffold(title: "Choose your first lesson",
                    subtitle: "I'll show you how it works.",
                    cta: "Start the lesson",
                    ctaEnabled: user.profile.firstCourse != nil, onNext: onNext) {
            VStack(spacing: 10) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { i, artwork in
                    let selected = user.profile.firstCourse == artwork.id
                    Button {
                        Haptics.selection()
                        user.profile.firstCourse = artwork.id
                    } label: {
                        HStack(spacing: 14) {
                            ArtImage(name: artwork.image)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artwork.title).font(.bodyStrong).foregroundStyle(Palette.ink)
                                Text(artwork.meta).font(.aCaption).foregroundStyle(Palette.muted)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if selected {
                                CheckBadge().transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(10)
                        .padding(.trailing, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Palette.mistLight : Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.pressable)
                    .animation(.snappy, value: selected)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .enter(Double(i) + 2)
                }
            }
        }
    }
}

// MARK: Your phone takes your attention, art gives it back

struct AttentionScreen: View {
    let onNext: () -> Void

    var body: some View {
        StoryScaffold(image: "ill_phone",
                      title: "Your phone takes your attention. Art gives it back.",
                      subtitle: "A few minutes with a single painting, and everything slows down.",
                      onNext: onNext)
    }
}

// MARK: After the guided tour

struct AfterLessonScreen: View {
    let onNext: () -> Void

    var body: some View {
        MascotTalkScreen(lines: [
            "This is how you'll learn from now on. Before we finish, let's build your program."
        ], cta: "Build my program", onNext: onNext)
    }
}
