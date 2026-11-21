import SwiftUI
import AuthenticationServices

// MARK: 17 · Rappel (curseur et soleil)

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
    if minutes < 540 { return "Au petit-déjeuner" }
    if minutes < 720 { return "Dans la matinée" }
    if minutes < 840 { return "À la pause déjeuner" }
    if minutes < 1080 { return "Dans l'après-midi" }
    if minutes < 1230 { return "En rentrant" }
    return "Avant de dormir"
}

struct ReminderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onNext: () -> Void
    @State private var minutes: Double = 510

    var body: some View {
        OnbScaffold(title: "À quelle heure veux-tu ton œuvre ?",
                    subtitle: "Une seule notification par jour, promis.",
                    cta: "Activer le rappel à \(formatMinutes(Int(minutes)))",
                    onNext: activate, secondaryTitle: "Plus tard", onSecondary: skip) {
            SunScene(minutes: minutes)
                .frame(height: 250)
                .appearUp(0.1)
            VStack(spacing: 2) {
                Text(formatMinutes(Int(minutes)))
                    .font(.figtree(40, .semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(momentLabel(Int(minutes))).font(.figtree(15)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 2) {
                Slider(value: $minutes, in: 360...1380, step: 15)
                    .tint(Palette.blue)
                    .accessibilityLabel("Heure du rappel")
                HStack {
                    Text("6 h"); Spacer(); Text("midi"); Spacer(); Text("18 h"); Spacer(); Text("23 h")
                }
                .font(.aCaption)
                .foregroundStyle(Palette.muted)
            }
        }
        .onAppear { minutes = Double(user.profile.reminderMinutes) }
        .onChange(of: minutes) { _, _ in Haptics.selection() }
    }

    private func activate() {
        user.profile.reminderMinutes = Int(minutes)
        Task {
            let granted = await Reminder.requestPermission()
            await MainActor.run {
                user.profile.reminderOn = granted
                if granted {
                    Reminder.scheduleDaily(atMinutes: Int(minutes))
                    Haptics.success()
                }
                onNext()
            }
        }
    }

    private func skip() {
        user.profile.reminderMinutes = Int(minutes)
        user.profile.reminderOn = false
        onNext()
    }
}

// MARK: Chargement

struct LoadingScreen: View {
    let onNext: () -> Void
    @State private var progress = 0
    @State private var timer: Timer?

    private let rows = [
        "Analyse de tes réponses",
        "Réglage de ton niveau de départ",
        "Choix de ton premier parcours",
        "Programmation de ton rappel"
    ]

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(progress) / 100)
                    .stroke(Palette.blue, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                Text("\(progress) %")
                    .font(.figtree(40, .semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: 176, height: 176)

            VStack(spacing: 8) {
                Text("On prépare ton programme").font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                Text("D'après tes réponses, rien que pour toi.").font(.aBody).foregroundStyle(Palette.muted)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    let done = progress >= (i + 1) * 25
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(done ? Palette.green : Color(hex: 0xD9CFC8)))
                            .scaleEffect(done ? 1 : 0.85)
                        Text(row)
                            .font(.figtree(15, .medium))
                            .foregroundStyle(done ? Palette.ink : Palette.muted)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 52)
                    .animation(.bouncy, value: done)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))

            Spacer(minLength: 0)

            if progress >= 100 {
                Button("Voir mon programme") { onNext() }
                    .buttonStyle(.primary)
                    .transition(.opacity.combined(with: .offset(y: 16)))
            } else {
                Text("Encore un instant…").font(.aSmall).foregroundStyle(Palette.muted).frame(height: 56)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { t in
            if progress >= 100 {
                t.invalidate()
                return
            }
            withAnimation(.gentle) { progress += 2 }
            if progress % 25 == 0 { Haptics.press() } else if progress % 6 == 0 { Haptics.rigid() }
            if progress >= 100 { Haptics.success() }
        }
    }
}

// MARK: 18 · Ton programme

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

    private var movement: Movement? {
        content.movement(content.artwork(user.profile.firstCourse)?.movementId) ?? content.movements.first
    }

    var body: some View {
        OnbScaffold(title: "Dans 30 jours",
                    subtitle: "Voici où tu en seras, à ton rythme.", cta: "Ça me va", onNext: onNext) {
            Group {
                if picking {
                    AvatarPicker(selection: $user.profile.avatar) {
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
                            Text("Ton avatar").font(.bodyStrong).foregroundStyle(Palette.ink)
                            Text("Visible sur ton profil").font(.aCaption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                        Button("Modifier") {
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
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            .appearUp(0.05)

            if let movement, let cover = content.artwork(movement.cover) {
                HStack(spacing: 0) {
                    ArtImage(name: cover.image).frame(width: 104, height: 112)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ton premier parcours").font(.figtree(12, .semibold))
                        Text(movement.name).font(.aCardTitle)
                        Text(movement.summary).font(.aCaption)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    Spacer(minLength: 0)
                }
                .background(Palette.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .appearUp(0.15)
            }

            HStack(spacing: 10) {
                projection("\(min(30, content.artworks.count))", "œuvres")
                projection(hoursIn30Days, "de regard")
                projection("\(max(1, user.profile.movements.count))", user.profile.movements.count > 1 ? "courants" : "courant")
            }
            .appearUp(0.2)

            VStack(spacing: 0) {
                recap("Objectif", user.profile.goal ?? "À définir")
                Divider()
                recap("Chaque jour", "\(user.profile.minutes) min")
                Divider()
                recap("Rappel", user.profile.reminderOn ? formatMinutes(user.profile.reminderMinutes) : "Désactivé")
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            .appearUp(0.25)
        }
    }

    /// Temps de regard cumulé sur 30 jours, d'après le rythme choisi.
    private var hoursIn30Days: String {
        let minutes = user.profile.minutes * 30
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60)"
    }

    private func projection(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.figtree(24, .semibold))
            Text(label).font(.figtree(13, .medium))
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.blueSoft))
    }

    private func recap(_ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.aSmall).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Text(value).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .frame(minHeight: 48)
    }
}

// MARK: 19 · Compte

struct AccountScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 8) {
                Text("Garde ta série et ta collection")
                    .font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                Text("Un compte pour ne rien perdre si tu changes de téléphone.")
                    .font(.aBody).foregroundStyle(Palette.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, -24)
            .appearUp(0.1)

            Spacer(minLength: 16)

            VStack(spacing: 10) {
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

                Button("Continuer sans compte") { onNext() }
                    .buttonStyle(.secondary)

                Text("En continuant, tu acceptes les conditions d'utilisation et la politique de confidentialité.")
                    .font(.figtree(12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .appearUp(0.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
