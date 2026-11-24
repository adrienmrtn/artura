import SwiftUI
import AuthenticationServices
import StoreKit

// MARK: Reminder (slider and sun)

/// Small landscape where the sun follows the chosen time.
struct SunScene: View {
    /// Minutes since midnight (360 = 6 AM, 1380 = 11 PM).
    let minutes: Double

    private var isNight: Bool { minutes >= 1230 }
    private var progress: Double { min(1, max(0, (minutes - 360) / (1230 - 360))) }

    private var sky: Color {
        if minutes < 450 { return Color(hex: 0xFFB7A8) }
        if minutes < 1050 { return Color(hex: 0x5AAEF7) }
        if minutes < 1230 { return Color(hex: 0xFF9466) }
        return Color(hex: 0x1B2A6B)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sunX = 40 + progress * (w - 80)
            let sunY = isNight ? h + 60 : h * 0.72 - sin(.pi * progress) * h * 0.56
            ZStack {
                sky
                // Stars and moon
                Group {
                    Circle().fill(.white).frame(width: 6, height: 6).position(x: w * 0.12, y: h * 0.16)
                    Circle().fill(.white).frame(width: 4, height: 4).position(x: w * 0.36, y: h * 0.3)
                    Circle().fill(.white).frame(width: 5, height: 5).position(x: w * 0.58, y: h * 0.13)
                    Circle().fill(.white).frame(width: 4, height: 4).position(x: w * 0.88, y: h * 0.38)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: 0xFDF6E3))
                        .position(x: w * 0.76, y: h * 0.22)
                }
                .opacity(isNight ? 1 : 0)
                // Daytime cloud
                Capsule().fill(.white).frame(width: 86, height: 28)
                    .position(x: w * 0.22, y: h * 0.3)
                    .opacity(minutes >= 450 && minutes < 1050 ? 1 : 0)
                // Sun
                Circle()
                    .fill(Color(hex: 0xFFC533))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color(hex: 0xFFC533, opacity: 0.28)).frame(width: 84, height: 84))
                    .position(x: sunX, y: sunY)
                // Hills
                HillShape(seed: 0).fill(isNight ? Color(hex: 0x14463A) : Color(hex: 0x3FA36B))
                HillShape(seed: 1).fill(isNight ? Color(hex: 0x0E3029) : Color(hex: 0x2E8555))
            }
            .animation(.easeInOut(duration: 0.4), value: sky)
            .animation(.snappy, value: minutes)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct HillShape: Shape {
    let seed: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let base = rect.maxY
        let top = rect.maxY - rect.height * (seed == 0 ? 0.3 : 0.18)
        p.move(to: CGPoint(x: rect.minX, y: base))
        p.addLine(to: CGPoint(x: rect.minX, y: top + 20))
        if seed == 0 {
            p.addCurve(to: CGPoint(x: rect.maxX, y: top + 6),
                       control1: CGPoint(x: rect.width * 0.3, y: top - 50),
                       control2: CGPoint(x: rect.width * 0.65, y: top + 46))
        } else {
            p.addCurve(to: CGPoint(x: rect.maxX, y: top + 12),
                       control1: CGPoint(x: rect.width * 0.35, y: top - 34),
                       control2: CGPoint(x: rect.width * 0.7, y: top + 38))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: base))
        p.closeSubpath()
        return p
    }
}

func momentLabel(_ minutes: Int) -> String {
    if minutes < 540 { return L("At breakfast") }
    if minutes < 720 { return L("In the morning") }
    if minutes < 840 { return L("At lunch break") }
    if minutes < 1080 { return L("In the afternoon") }
    if minutes < 1230 { return L("In the evening") }
    return L("Before bed")
}

struct ReminderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    /// Slider position, continuous. The kept time is rounded to the quarter hour.
    @State private var raw: Double = 510

    private var minutes: Int { Int((raw / 15).rounded()) * 15 }

    var body: some View {
        OnbScaffold(title: L("What time would you like to do your daily learning?"),
                    subtitle: L("Just one notification a day, promise."),
                    spoken: true,
                    cta: L("Remind me at %@", formatMinutes(minutes)),
                    onNext: activate, secondaryTitle: L("Later"), onSecondary: skip) {
            SunScene(minutes: raw)
                .frame(height: 168)
                .enter(2)
            VStack(spacing: 2) {
                Text(formatMinutes(minutes))
                    .font(.figtree(40, .bold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                    .animation(.snappy, value: minutes)
                Text(momentLabel(minutes)).font(.figtree(15)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .enter(3)
            VStack(spacing: 2) {
                Slider(value: $raw, in: 360...1380)
                    .tint(Palette.blue)
                    .accessibilityLabel(L("Reminder time"))
                    .accessibilityValue(formatMinutes(minutes))
                HStack {
                    Text(L("6 AM")); Spacer(); Text(L("noon")); Spacer(); Text(L("6 PM")); Spacer(); Text(L("11 PM"))
                }
                .font(.aCaption)
                .foregroundStyle(Palette.muted)
            }
            .enter(4)
        }
        .onAppear { raw = Double(user.profile.reminderMinutes) }
        // One tick per quarter hour crossed, not on every finger move.
        .onChange(of: minutes) { _, _ in Haptics.selection() }
    }

    private func activate() {
        let chosen = minutes
        user.profile.reminderMinutes = chosen
        Task {
            let granted = await Reminder.requestPermission()
            await MainActor.run {
                user.profile.reminderOn = granted
                if granted {
                    Reminder.scheduleDaily(atMinutes: chosen)
                    Haptics.success()
                }
                onNext()
            }
        }
    }

    private func skip() {
        user.profile.reminderMinutes = minutes
        user.profile.reminderOn = false
        onNext()
    }
}

// MARK: The widget: the artwork of the day without opening the app

/// Phone outline around a drawn screen.
private struct PhoneMockup<Screen: View>: View {
    @ViewBuilder var screen: () -> Screen

    var body: some View {
        screen()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(alignment: .top) {
                Capsule().fill(.black).frame(width: 76, height: 22).padding(.top, 10)
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 41, style: .continuous).fill(Palette.blueDark))
            .aspectRatio(0.5, contentMode: .fit)
    }
}

struct WidgetScreen: View {
    @EnvironmentObject private var content: ContentStore
    let onNext: () -> Void

    /// False: Lock Screen. True: Home Screen.
    @State private var home = OnboardingDebug.flag("onbWidgetHome")
    @State private var popped = false

    private var artwork: Artwork? { content.artwork("nuit") ?? content.artworks.first }

    private var today: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLanguage.locale))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(L("Your daily masterpiece, without even opening the app."))
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("On your Lock Screen, and on your Home Screen."))
                    .font(.figtree(17))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .enter()

            PhoneMockup {
                ZStack {
                    if home {
                        homeScreen.transition(.opacity)
                    } else {
                        lockScreen.transition(.opacity)
                    }
                }
            }
            .frame(maxHeight: 430)
            .padding(.top, 20)
            .enter(2)
            .accessibilityHidden(true)

            Spacer(minLength: 16)

            Button(home ? L("Continue") : L("And on the Home Screen?")) {
                if home {
                    onNext()
                } else {
                    popped = false
                    withAnimation(.settle) { home = true }
                    withAnimation(.settle.delay(0.25)) { popped = true }
                }
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
        .onAppear {
            withAnimation(.settle.delay(0.7)) { popped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { Haptics.soft() }
        }
    }

    private var wallpaper: some View {
        LinearGradient(colors: [Color(hex: 0x16294A), Color(hex: 0x3D5E93)], startPoint: .top, endPoint: .bottom)
    }

    private var lockScreen: some View {
        ZStack {
            wallpaper
            VStack(spacing: 2) {
                Text(today)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 44)
                Text("9:41")
                    .font(.system(size: 62, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                // The Lock Screen widget
                HStack(spacing: 10) {
                    if let artwork {
                        ArtImage(name: artwork.image)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("Artwork of the day"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(artwork?.title ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(artwork?.artist ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .scaleEffect(popped ? 1 : 0.86)
                .opacity(popped ? 1 : 0)
                Spacer()
                HStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 36, height: 36)
                    Spacer()
                    Circle().fill(.white.opacity(0.18)).frame(width: 36, height: 36)
                }
                .padding(.horizontal, 26)
                Capsule().fill(.white.opacity(0.8)).frame(width: 84, height: 4).padding(.top, 10).padding(.bottom, 8)
            }
        }
    }

    /// A real Home Screen with the Artura widget (screenshot taken on an iPhone).
    private var homeScreen: some View {
        Image("widget_home")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .scaleEffect(popped ? 1 : 1.04)
            .opacity(popped ? 1 : 0)
    }
}

// MARK: Made by art lovers, for art lovers

/// A word from the team, and the App Store rating prompt half a second after the screen appears.
struct MadeByScreen: View {
    let onNext: () -> Void
    @Environment(\.requestReview) private var requestReview
    /// The prompt is asked once per launch, even if the visitor comes back to this screen.
    private static var asked = false

    var body: some View {
        StoryScaffold(image: "ill_amateurs",
                      title: L("Artura was made by art lovers, for art lovers."),
                      subtitle: L("If you like it too, a few stars help other curious minds find us."),
                      onNext: onNext)
            .task {
                guard !Self.asked else { return }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, !Self.asked else { return }
                Self.asked = true
                Analytics.track("rating_prompt", ["from": "onboarding"])
                requestReview()
            }
    }
}

// MARK: Loading: building your program

struct LoadingScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    /// Progress from 0 to 100, animated continuously.
    @State private var progress: Double = 0
    /// Number of completed steps.
    @State private var stage = 0
    /// Paintings already shown in the backdrop.
    @State private var shown = 0

    private let rows = [
        L("Analyzing your answers"),
        L("Setting your starting level"),
        L("Choosing your first lesson"),
        L("Scheduling your reminder")
    ]
    private let stepDuration = 0.95

    private var isDone: Bool { stage >= rows.count }

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return L("%@, we're building your program", name)
        }
        return L("Building your program")
    }

    var body: some View {
        ZStack {
            // Paintings and a sculpture float behind, coming in as the loading progresses.
            FloatingSpace(shown: shown, withSculpture: true)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // The Mona Lisa at the center of the progress ring
                ZStack {
                    Circle().fill(Palette.mist)
                    Image("joconde")
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 14)
                        .clipShape(Circle())
                    Circle().stroke(Palette.line, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress / 100))
                        .stroke(Palette.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 164, height: 164)
                .accessibilityHidden(true)

                CountingText(value: progress, suffix: "%")
                    .font(.figtree(40, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 14)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.figtree(26, .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Based on your answers, just for you."))
                        .font(.aBody)
                        .foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .background(Palette.bg.opacity(0.92).blur(radius: 14).padding(-12))

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        let done = stage > i
                        let active = stage == i
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(done ? Palette.green : (active ? Palette.mist : Palette.line))
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                } else if active {
                                    ProgressView().controlSize(.mini).tint(Palette.blue)
                                }
                            }
                            .frame(width: 26, height: 26)
                            Text(row)
                                .font(.figtree(15, done || active ? .semibold : .regular))
                                .foregroundStyle(done || active ? Palette.ink : Palette.muted)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 46)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
                .padding(.top, 20)

                Spacer(minLength: 16)

                if isDone {
                    Button(L("See my program")) { onNext() }
                        .buttonStyle(.primary)
                        .transition(.opacity.combined(with: .offset(y: 16)))
                } else {
                    Text(L("Just a moment…"))
                        .font(.aSmall)
                        .foregroundStyle(Palette.muted)
                        .frame(height: 59)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .onAppear(perform: start)
    }

    private func start() {
        guard stage == 0, progress == 0 else { return }
        for i in 1...rows.count {
            let at = 0.5 + Double(i - 1) * (stepDuration + 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + at) {
                withAnimation(.easeInOut(duration: stepDuration)) {
                    progress = Double(i) * 100 / Double(rows.count)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + at + stepDuration) {
                withAnimation(.gentle) { stage = i }
                if i == rows.count { Haptics.success() } else { Haptics.press() }
            }
        }
        for i in 1...FloatingSpace.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * 0.3) {
                shown = max(shown, i)
            }
        }
    }
}

// MARK: Your program

struct AvatarPicker: View {
    @Binding var selection: Int
    var size: CGFloat = 56
    var onPick: (() -> Void)? = nil

    var body: some View {
        HStack {
            ForEach(Array(avatarImages.enumerated()), id: \.offset) { i, image in
                Button {
                    Haptics.selection()
                    withAnimation(.bouncy) { selection = i }
                    onPick?()
                } label: {
                    ArtImage(name: image)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .padding(3)
                        .overlay(Circle().stroke(selection == i ? Palette.blue : .clear, lineWidth: 3))
                        .scaleEffect(selection == i ? 1.04 : 1)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(avatarLabels[i])
                if i < avatarImages.count - 1 { Spacer(minLength: 0) }
            }
        }
    }
}

struct PlanScreen: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let onNext: () -> Void
    @State private var picking = false

    /// The movement of the first lesson: the first path of the program.
    private var movement: Movement? {
        content.movement(content.artwork(user.profile.firstCourse)?.movementId) ?? content.movements.first
    }

    /// Soft mauve behind the avatar block.
    private static let mauve = Color(hex: 0xEDE3FF)

    var body: some View {
        OnbScaffold(title: L("In 30 days"),
                    subtitle: L("Here's where you'll be, at your own pace."),
                    cta: L("Sounds good"), onNext: onNext) {
            Group {
                if picking {
                    AvatarPicker(selection: $user.profile.avatar, size: 52) {
                        withAnimation(.gentle) { picking = false }
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 14) {
                        ArtImage(name: avatarImages[min(user.profile.avatar, avatarImages.count - 1)])
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Your avatar")).font(.bodyStrong).foregroundStyle(Palette.ink)
                            Text(L("Shown on your profile")).font(.aCaption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                        Button(L("Change")) {
                            Haptics.tap()
                            withAnimation(.gentle) { picking = true }
                        }
                        .font(.figtree(14, .semibold))
                        .foregroundStyle(Palette.blueText)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Capsule().fill(.white))
                        .buttonStyle(.pressable)
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Self.mauve))
            .enter(1)

            if let movement, let cover = content.artwork(movement.cover) {
                HStack(spacing: 0) {
                    ArtImage(name: cover.image).frame(width: 104, height: 112)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Your first path")).font(.figtree(12, .semibold))
                        Text(movement.name).font(.aCardTitle)
                        Text(movement.summary).font(.aCaption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    Spacer(minLength: 0)
                }
                .background(Palette.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .enter(2)
            }

            HStack(spacing: 10) {
                projection("\(min(30, content.artworks.count))", L("artworks"))
                projection(hoursIn30Days, L("of looking"))
                projection("\(max(1, min(content.movements.count, 3)))", L("movements"))
            }
            .enter(3)

            VStack(spacing: 0) {
                recap(L("Goal"), goalLabel)
                Divider()
                recap(L("Every day"), L("%@ min", "\(user.profile.minutes)"))
                Divider()
                recap(L("Reminder"), user.profile.reminderOn ? formatMinutes(user.profile.reminderMinutes) : L("Off"))
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            .enter(4)
        }
    }

    /// The first chosen motivation, with the count of the others.
    private var goalLabel: String {
        let goals = user.profile.goals ?? []
        guard let first = goals.first ?? user.profile.goal else { return L("Not set") }
        let shown = Self.goalName(first)
        return goals.count > 1 ? "\(shown) (+\(goals.count - 1))" : shown
    }

    /// Goals are stored in English (see MotivationScreen); this is the label shown.
    private static func goalName(_ goal: String) -> String {
        switch goal {
        case "Learn about art": return L("Learn about art")
        case "Become more cultured": return L("Become more cultured")
        case "Have new things to talk about": return L("Have new things to talk about")
        case "Prepare for an exam": return L("Prepare for an exam")
        case "Just for fun": return L("Just for fun")
        default: return goal
        }
    }

    /// Total viewing time over 30 days, based on the chosen pace.
    private var hoursIn30Days: String {
        let minutes = user.profile.minutes * 30
        return minutes % 60 == 0 ? L("%@ h", "\(minutes / 60)") : L("%@ h %@", "\(minutes / 60)", "\(minutes % 60)")
    }

    private func projection(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.figtree(24, .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.aSmall).foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.mist))
    }

    private func recap(_ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.aSmall).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Text(value).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .frame(minHeight: 52)
    }
}

// MARK: Social proof: learners and reviews

struct SocialProofScreen: View {
    let onNext: () -> Void
    @State private var stars = 0

    var body: some View {
        OnbScaffold(title: L("You're in good company"),
                    cta: L("Join them"), onNext: onNext) {
            // The number, between two laurels
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "laurel.leading")
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(Palette.yellow)
                    VStack(spacing: 0) {
                        Text("+ \(SocialProof.learners)")
                            .font(.figtree(38, .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(L("learners"))
                            .font(.figtree(17, .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(Palette.yellow)
                }
                HStack(spacing: 8) {
                    Text(SocialProof.rating)
                        .font(.figtree(17, .bold))
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.yellow)
                                .scaleEffect(i < stars ? 1 : 0.5)
                                .opacity(i < stars ? 1 : 0)
                        }
                    }
                    Text(L("on the App Store"))
                        .font(.figtree(15))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.mistLight))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.mist, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("More than %@ learners, rated %@ out of 5 on the App Store", SocialProof.learners, SocialProof.rating))
            .enter(2)

            VStack(spacing: 10) {
                ForEach(Array(SocialProof.reviews.enumerated()), id: \.offset) { i, review in
                    HStack(alignment: .top, spacing: 12) {
                        ArtImage(name: avatarImages[i % avatarImages.count])
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Palette.yellow)
                                }
                            }
                            Text(L("“%@”", review))
                                .font(.figtree(15, .medium))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card))
                    .enter(Double(i) * 1.5 + 4)
                }
            }
        }
        .onAppear {
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + 0.14 * Double(i)) {
                    withAnimation(.snappy) { stars = i }
                    Haptics.whisper()
                }
            }
        }
    }
}

// MARK: Account

struct AccountScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            // Grainy illustration at the top, under a tilted arc.
            ZStack(alignment: .top) {
                ArtImage(name: "ill_galerie", anchor: UnitPoint(x: 0.5, y: 0.7))
                    .frame(height: 320)
                    .clipShape(ArcHeaderShape())
                    .ignoresSafeArea(edges: .top)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(L("Back"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 8) {
                Text(L("Keep your streak and your collection"))
                    .font(.figtree(28, .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("An account so you don't lose anything if you change phones."))
                    .font(.aBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, -24)
            .enter(1)

            Spacer(minLength: 16)

            VStack(spacing: 8) {
                if let message {
                    Text(message)
                        .font(.aCaption)
                        .foregroundStyle(Palette.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SignInButtons(message: $message, onDone: onNext)

                TextLinkButton(title: L("Continue without an account"), action: onNext)

                Text(L("By continuing, you agree to the Terms of Use and the Privacy Policy."))
                    .font(.figtree(12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .enter(3)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}

// MARK: - Sign in with Apple / Google

/// The two sign-in buttons (Apple, then Google under it), used by the onboarding and the profile.
/// The identity is kept on the phone at once and `onDone` is called; the Supabase account (progress
/// saved online) is opened in the background, so a slow network never blocks the screen.
struct SignInButtons: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Binding var message: String?
    let onDone: () -> Void

    @State private var googleBusy = false
    /// Raw nonce of the Apple request in progress (its SHA-256 is given to Apple, the raw value to Supabase).
    @State private var appleNonce = ""

    /// The Google button only appears in a release build if sign-in is configured.
    private var showsGoogle: Bool { GoogleAuth.isConfigured || OnboardingDebug.isDebug }

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                let nonce = SupabaseAuth.makeNonce()
                appleNonce = nonce.raw
                request.requestedScopes = [.fullName]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        user.profile.appleUserId = credential.user
                        if let name = credential.fullName?.givenName { user.profile.firstName = name }
                        if let data = credential.identityToken, let token = String(data: data, encoding: .utf8) {
                            let nonce = appleNonce
                            Task { await user.connectAccount(provider: "apple", idToken: token, nonce: nonce) }
                        }
                    }
                    Haptics.success()
                    onDone()
                case .failure:
                    Haptics.warning()
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(Capsule())

            if showsGoogle {
                Button(action: signInWithGoogle) {
                    HStack(spacing: 10) {
                        if googleBusy {
                            ProgressView().tint(Palette.ink)
                        } else {
                            Image("google_g")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(L("Continue with Google"))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Palette.lip, lineWidth: 1.5))
                }
                .buttonStyle(.pressable)
                .disabled(googleBusy)
            }
        }
    }

    private func signInWithGoogle() {
        message = nil
        guard GoogleAuth.isConfigured else {
            Haptics.warning()
            message = L("Google sign-in isn't set up yet (client ID missing in GoogleAuth.swift).")
            return
        }
        googleBusy = true
        Task {
            do {
                let account = try await GoogleAuth.signIn(using: webAuthenticationSession)
                user.profile.googleUserId = account.userID
                if let name = account.firstName, (user.profile.firstName ?? "").isEmpty {
                    user.profile.firstName = name
                }
                googleBusy = false
                Haptics.success()
                Task { await user.connectAccount(provider: "google", idToken: account.idToken, nonce: nil) }
                onDone()
            } catch GoogleAuth.Failure.cancelled {
                googleBusy = false
            } catch {
                googleBusy = false
                Haptics.warning()
                message = L("Google sign-in failed. Please try again in a moment.")
            }
        }
    }
}
