import SwiftUI
import AuthenticationServices

// MARK: Rappel (curseur et soleil)

/// Petit paysage où le soleil suit l'heure choisie.
struct SunScene: View {
    /// Minutes depuis minuit (360 = 6 h, 1380 = 23 h).
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
                // Étoiles et lune
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
                // Nuage de jour
                Capsule().fill(.white).frame(width: 86, height: 28)
                    .position(x: w * 0.22, y: h * 0.3)
                    .opacity(minutes >= 450 && minutes < 1050 ? 1 : 0)
                // Soleil
                Circle()
                    .fill(Color(hex: 0xFFC533))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color(hex: 0xFFC533, opacity: 0.28)).frame(width: 84, height: 84))
                    .position(x: sunX, y: sunY)
                // Collines
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
    if minutes < 540 { return "At breakfast" }
    if minutes < 720 { return "In the morning" }
    if minutes < 840 { return "At lunch break" }
    if minutes < 1080 { return "In the afternoon" }
    if minutes < 1230 { return "In the evening" }
    return "Before bed"
}

struct ReminderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    /// Position du curseur, en continu. L'heure retenue est arrondie au quart d'heure.
    @State private var raw: Double = 510

    private var minutes: Int { Int((raw / 15).rounded()) * 15 }

    var body: some View {
        OnbScaffold(title: "What time would you like to do your daily learning?",
                    subtitle: "Just one notification a day, promise.",
                    spoken: true,
                    cta: "Remind me at \(formatMinutes(minutes))",
                    onNext: activate, secondaryTitle: "Later", onSecondary: skip) {
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
                    .accessibilityLabel("Reminder time")
                    .accessibilityValue(formatMinutes(minutes))
                HStack {
                    Text("6 AM"); Spacer(); Text("noon"); Spacer(); Text("6 PM"); Spacer(); Text("11 PM")
                }
                .font(.aCaption)
                .foregroundStyle(Palette.muted)
            }
            .enter(4)
        }
        .onAppear { raw = Double(user.profile.reminderMinutes) }
        // Un cran à chaque quart d'heure franchi, pas à chaque mouvement du doigt.
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

// MARK: Le widget : l'œuvre du jour sans ouvrir l'appli

/// Silhouette de téléphone autour d'un écran dessiné.
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

    /// Faux : écran verrouillé. Vrai : écran d'accueil.
    @State private var home = OnboardingDebug.flag("onbWidgetHome")
    @State private var popped = false

    private var artwork: Artwork? { content.artwork("nuit") ?? content.artworks.first }

    private var today: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US")))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Your daily masterpiece, without even opening the app.")
                    .font(.aTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("On your Lock Screen, and on your Home Screen.")
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

            Button(home ? "Continue" : "And on the Home Screen?") {
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
                // Le widget de l'écran verrouillé
                HStack(spacing: 10) {
                    if let artwork {
                        ArtImage(name: artwork.image)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Artwork of the day")
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

    private var homeScreen: some View {
        ZStack {
            wallpaper
            VStack(spacing: 14) {
                // Le widget de l'écran d'accueil : l'œuvre en grand
                ZStack(alignment: .bottomLeading) {
                    if let artwork {
                        ArtImage(name: artwork.image)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Artwork of the day")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(artwork?.title ?? "")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(10)
                }
                .frame(height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 50)
                .scaleEffect(popped ? 1 : 0.86)
                .opacity(popped ? 1 : 0)

                // Des applis factices, pour situer le widget
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.2))
                                .frame(width: 36, height: 36)
                            if column < 3 { Spacer(minLength: 0) }
                        }
                    }
                }
                Spacer()
                Capsule().fill(.white.opacity(0.8)).frame(width: 84, height: 4).padding(.bottom, 8)
            }
            .padding(.horizontal, 14)
        }
    }
}

// MARK: Chargement : on prépare ton programme

struct LoadingScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void

    /// Avancement de 0 à 100, animé en continu.
    @State private var progress: Double = 0
    /// Nombre d'étapes terminées.
    @State private var stage = 0
    /// Tableaux déjà apparus dans le décor.
    @State private var shown = 0

    private let rows = [
        "Analyzing your answers",
        "Setting your starting level",
        "Choosing your first lesson",
        "Scheduling your reminder"
    ]
    private let stepDuration = 0.95

    private var isDone: Bool { stage >= rows.count }

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "\(name), we're building your program"
        }
        return "Building your program"
    }

    var body: some View {
        ZStack {
            // Tableaux et sculpture flottent derrière, et arrivent au fil du chargement.
            FloatingSpace(shown: shown, withSculpture: true)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // La Joconde au centre de l'anneau de progression
                ZStack {
                    Circle().fill(Palette.sand)
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
                    Text("Based on your answers, just for you.")
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
                                Circle().fill(done ? Palette.green : (active ? Palette.sand : Palette.line))
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
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
                .padding(.top, 20)

                Spacer(minLength: 16)

                if isDone {
                    Button("See my program") { onNext() }
                        .buttonStyle(.primary)
                        .transition(.opacity.combined(with: .offset(y: 16)))
                } else {
                    Text("Just a moment…")
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

// MARK: Ton programme

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

    /// Le premier tableau du programme : celui de la visite guidée.
    private var firstArtwork: Artwork? {
        content.artwork(user.profile.firstCourse) ?? content.artwork("nuit") ?? content.artworks.first
    }

    private var title: String {
        if let name = user.profile.firstName, !name.isEmpty {
            return "\(name), here's your program."
        }
        return "Here's your program."
    }

    var body: some View {
        OnbScaffold(title: title,
                    subtitle: "Here's where you'll be in 30 days.",
                    spoken: true, cta: "Sounds good", onNext: onNext) {
            HStack(spacing: 10) {
                projection("\(min(30, content.artworks.count))", "artworks")
                projection(hoursIn30Days, "of art")
                projection("30", "day streak")
            }
            .enter(2)

            if let first = firstArtwork {
                HStack(spacing: 14) {
                    ArtImage(name: first.image)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        TagPill(text: "Your first masterpiece")
                        Text(first.title).font(.aCardTitle).foregroundStyle(Palette.ink)
                        Text(first.meta).font(.aCaption).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
                .enter(3)
            }

            VStack(spacing: 0) {
                recap("target", "Goal", goalLabel)
                divider
                recap("clock.fill", "Every day", "\(user.profile.minutes) min")
                divider
                recap("bell.fill", "Reminder", user.profile.reminderOn ? formatMinutes(user.profile.reminderMinutes) : "Off")
                divider
                avatarRow
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
            .enter(4)
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.line).frame(height: 1)
    }

    /// La première motivation choisie, avec le nombre des autres.
    private var goalLabel: String {
        let goals = user.profile.goals ?? []
        guard let first = goals.first ?? user.profile.goal else { return "Not set" }
        return goals.count > 1 ? "\(first) (+\(goals.count - 1))" : first
    }

    /// Temps de regard cumulé sur 30 jours, d'après le rythme choisi.
    private var hoursIn30Days: String {
        let minutes = user.profile.minutes * 30
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)"
    }

    private func projection(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.figtree(24, .bold)).foregroundStyle(Palette.blue)
            Text(label).font(.figtree(13, .medium)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.sandLight))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.sand, lineWidth: 1))
    }

    private func recap(_ symbol: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.sand))
            Text(label).font(.aSmall).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Text(value).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .frame(minHeight: 52)
    }

    /// L'avatar du profil, modifiable sur place.
    private var avatarRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ArtImage(name: avatarImages[min(user.profile.avatar, avatarImages.count - 1)])
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                Text("Your avatar").font(.aSmall).foregroundStyle(Palette.muted)
                Spacer(minLength: 8)
                Button(picking ? "Close" : "Change") {
                    Haptics.tap()
                    withAnimation(.gentle) { picking.toggle() }
                }
                .font(.figtree(14, .semibold))
                .foregroundStyle(Palette.blue)
                .frame(height: 44)
                .buttonStyle(.pressable)
            }
            .frame(minHeight: 52)
            if picking {
                AvatarPicker(selection: $user.profile.avatar, size: 48) {
                    withAnimation(.gentle) { picking = false }
                }
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
    }
}

// MARK: Preuve sociale : apprenants et avis

struct SocialProofScreen: View {
    let onNext: () -> Void
    @State private var stars = 0

    var body: some View {
        OnbScaffold(title: "You're in good company",
                    cta: "Join them", onNext: onNext) {
            // Le chiffre, entre deux lauriers
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
                        Text("learners")
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
                    Text("on the App Store")
                        .font(.figtree(15))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.sandLight))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.sand, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("More than \(SocialProof.learners) learners, rated \(SocialProof.rating) out of 5 on the App Store")
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
                            Text("“\(review)”")
                                .font(.figtree(15, .medium))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1))
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

// MARK: Compte

struct AccountScreen: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var googleBusy = false
    @State private var message: String?

    /// Le bouton Google n'apparaît en version publiée que si la connexion est configurée.
    private var showsGoogle: Bool { GoogleAuth.isConfigured || OnboardingDebug.isDebug }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.pressable)
                .padding(.leading, -12)
                .accessibilityLabel("Back")
                Spacer()
            }
            .frame(height: 44)
            .padding(.top, 8)

            Spacer(minLength: 8)

            MascotBubble(mascotSize: 132) {
                VStack(spacing: 6) {
                    Text("Keep your streak and your collection.")
                        .font(.figtree(24, .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("An account so you don't lose anything if you change phones.")
                        .font(.figtree(15))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .enter()

            // Ce que le compte conserve
            HStack(spacing: 8) {
                keep("flame.fill", "Your streak")
                keep("heart.fill", "Your favorites")
                keep("map.fill", "Your program")
            }
            .padding(.top, 14)
            .enter(2)

            Spacer(minLength: 10)
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if let message {
                    Text(message)
                        .font(.aCaption)
                        .foregroundStyle(Palette.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            user.profile.appleUserId = credential.user
                            if let name = credential.fullName?.givenName { user.profile.firstName = name }
                        }
                        Haptics.success()
                        onNext()
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
                                Text("Continue with Google")
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

                TextLinkButton(title: "Continue without an account", action: onNext)

                Text("By continuing, you agree to the Terms of Use and the Privacy Policy.")
                    .font(.figtree(12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .enter(3)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }

    private func keep(_ symbol: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Palette.sand))
            Text(label)
                .font(.figtree(13, .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func signInWithGoogle() {
        message = nil
        guard GoogleAuth.isConfigured else {
            Haptics.warning()
            message = "Google sign-in isn't set up yet (client ID missing in GoogleAuth.swift)."
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
                onNext()
            } catch GoogleAuth.Failure.cancelled {
                googleBusy = false
            } catch {
                googleBusy = false
                Haptics.warning()
                message = "Google sign-in failed. Please try again in a moment."
            }
        }
    }
}
