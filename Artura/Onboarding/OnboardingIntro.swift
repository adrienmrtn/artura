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
    /// Number of quotes revealed so far, none at first: each tap brings the next one, then the screen moves on.
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

// MARK: Story pages revealed tap by tap

/// An illustration, then a tag and a title, then a text: each tap brings the next block.
/// Once everything is there, a tap anywhere moves on.
struct TapStoryScreen: View {
    let image: String
    let tag: String
    let title: String
    let text: String
    let onNext: () -> Void

    /// Blocks revealed so far: 0 = the illustration alone, 1 = tag and title, 2 = the text.
    @State private var shown = 0
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ArtImage(name: image, zoom: drift ? 1.09 : 1)
                .frame(minHeight: 180, maxHeight: 330)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .enter()

            VStack(spacing: 12) {
                TagPill(text: tag)
                Text(title)
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 28)
            .opacity(shown >= 1 ? 1 : 0)
            .offset(y: shown >= 1 ? 0 : 18)

            Text(text)
                .font(.figtree(17))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .opacity(shown >= 2 ? 1 : 0)
                .offset(y: shown >= 2 ? 0 : 18)

            Spacer(minLength: 16)

            TapHint()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .accessibilityAddTraits(.isButton)
        .onAppear {
            shown = min(max(0, OnboardingDebug.int("onbShown")), 2)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private func advance() {
        if shown < 2 {
            withAnimation(.settle) { shown += 1 }
            Haptics.soft()
        } else {
            Haptics.tap()
            onNext()
        }
    }
}

// MARK: The Chicago study

struct StudyScreen: View {
    let onNext: () -> Void

    var body: some View {
        TapStoryScreen(image: "ill_regard",
                       tag: "A study at the Art Institute of Chicago",
                       title: "26 seconds in front of a painting",
                       text: "That's how long a visitor looks at a masterpiece, on average. Barely enough to read the label.",
                       onNext: onNext)
    }
}

// MARK: Looking can be learned

struct LearnToLookScreen: View {
    let onNext: () -> Void

    var body: some View {
        TapStoryScreen(image: "ill_oeil",
                       tag: "Artura will help",
                       title: "Looking can be learned",
                       text: "Nobody is born knowing how to read a painting. Every day, I show you where to rest your eyes: a detail, a color, a gesture.",
                       onNext: onNext)
    }
}

// MARK: What you'll be able to do

/// A jagged crack running across a card.
private struct CrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [
            (0.0, 0.42), (0.14, 0.58), (0.27, 0.36), (0.41, 0.66), (0.5, 0.44),
            (0.62, 0.7), (0.74, 0.38), (0.87, 0.6), (1.0, 0.46)
        ]
        var p = Path()
        for (i, point) in points.enumerated() {
            let at = CGPoint(x: rect.minX + rect.width * point.0, y: rect.minY + rect.height * point.1)
            if i == 0 { p.move(to: at) } else { p.addLine(to: at) }
        }
        // Two small branches
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.36))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.08))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.7))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY + rect.height * 0.96))
        return p
    }
}

/// One ability: a locked box that cracks, bursts into pieces, then shows what it held.
private struct AbilityBox: View {
    let image: String
    let title: String
    let text: String
    /// 0: locked, 1: cracking, 2: open.
    let state: Int

    @State private var burst = false

    var body: some View {
        ZStack {
            // What the box holds
            HStack(spacing: 14) {
                ArtImage(name: image)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.aHeading).foregroundStyle(Palette.ink)
                    Text(text)
                        .font(.aSmall)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.mistLight))
            .opacity(state >= 2 ? 1 : 0)
            .scaleEffect(state >= 2 ? 1 : 0.92)

            // The locked lid, with its crack
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.card)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.lip)
                }
                .overlay {
                    CrackShape()
                        .trim(from: 0, to: state >= 1 ? 1 : 0)
                        .stroke(Palette.ink.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 6)
                }
                .frame(minHeight: 96)
                .opacity(state >= 2 ? 0 : 1)
                .scaleEffect(state >= 2 ? 1.06 : 1)
                .offset(x: state == 1 ? 3 : 0)

            // The pieces flying away
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi + 0.3
                RoundedRectangle(cornerRadius: 3)
                    .fill(i % 3 == 0 ? Palette.lip : Palette.card)
                    .frame(width: CGFloat(10 + (i * 7) % 12), height: CGFloat(8 + (i * 5) % 10))
                    .rotationEffect(.degrees(burst ? Double(i * 53 % 360) : 0))
                    .offset(x: burst ? CGFloat(cos(angle)) * CGFloat(110 + (i * 17) % 60) : 0,
                            y: burst ? CGFloat(sin(angle)) * CGFloat(60 + (i * 11) % 40) : 0)
                    .opacity(state >= 2 && !burst ? 1 : 0)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: state) { _, new in
            guard new >= 2 else { return }
            withAnimation(.easeOut(duration: 0.6)) { burst = true }
        }
        .onAppear { if state >= 2 { burst = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state >= 2 ? "\(title). \(text)" : "Locked")
    }
}

struct AbilitiesScreen: View {
    let onNext: () -> Void

    private let abilities: [(image: String, title: String, text: String)] = [
        ("ill_oeil", "Look", "Spot what matters in a painting, even one you've never seen."),
        ("ill_galerie", "Understand", "Who painted it, when, and why it changed everything."),
        ("ill_goal_talk", "Talk about it", "Have something to say at the museum, or over dinner.")
    ]

    /// Boxes already open.
    @State private var opened = min(max(0, OnboardingDebug.int("onbShown")), 3)
    /// Index of the box that is cracking, if any.
    @State private var cracking: Int?

    private var title: String {
        switch opened {
        case 0: return "Soon, you'll know how to"
        case 1: return "You'll learn how to look"
        case 2: return "…how to understand"
        default: return "…and how to talk about it"
        }
    }

    var body: some View {
        OnbScaffold(title: title,
                    subtitle: "A few minutes a day is all it takes.",
                    ctaEnabled: cracking == nil, onNext: advance) {
            VStack(spacing: 12) {
                ForEach(Array(abilities.enumerated()), id: \.offset) { i, ability in
                    AbilityBox(image: ability.image, title: ability.title, text: ability.text,
                               state: i < opened ? 2 : (cracking == i ? 1 : 0))
                        .enter(Double(i) + 2)
                }
            }
        }
        .animation(.gentle, value: opened)
    }

    /// Each press cracks the next box open; once all three are open, the button moves on.
    private func advance() {
        guard cracking == nil else { return }
        guard opened < abilities.count else {
            onNext()
            return
        }
        let index = opened
        Haptics.rigid()
        withAnimation(.easeOut(duration: 0.45)) { cracking = index }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            Haptics.heavy()
            withAnimation(.easeOut(duration: 0.3)) {
                opened = index + 1
                cracking = nil
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
