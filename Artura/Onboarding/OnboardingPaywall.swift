import SwiftUI
import StoreKit

// Fin de l'onboarding : la surprise, le cadeau (essai gratuit), « aucun engagement »,
// le déroulé de l'essai, puis l'offre de dernière minute si on veut partir.

enum Legal {
    /// Conditions d'utilisation : le contrat standard d'Apple, à remplacer si l'appli a les siennes.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Politique de confidentialité : à renseigner avant la mise en ligne.
    static let privacy: URL? = nil
}

private func dayCountWord(_ days: Int) -> String {
    switch days {
    case 3: return "Three"
    case 7: return "Seven"
    case 14: return "Fourteen"
    default: return "\(days)"
    }
}

// MARK: - Dessin isométrique (boîte cadeau)

/// Projette un point (x, y, z) d'un cube unité vers l'écran, en vue isométrique.
/// Le coin le plus proche du regard, (1, 1, 0), tombe en bas au centre du cadre.
private struct Iso {
    let rect: CGRect
    var unit: CGFloat { rect.width / 1.732 }

    func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: rect.midX + (x - y) * 0.866 * unit,
                y: rect.maxY - unit + (x + y) * 0.5 * unit - z * unit)
    }
}

/// Une face plane définie par ses coins dans l'espace du cube.
private struct IsoFace: Shape {
    let corners: [[CGFloat]]

    func path(in rect: CGRect) -> Path {
        let iso = Iso(rect: rect)
        var p = Path()
        for (i, c) in corners.enumerated() {
            let point = iso.point(c[0], c[1], c[2])
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// Le nœud du ruban, posé au centre du couvercle.
private struct IsoBow: Shape {
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = Iso(rect: rect).point(0.5, 0.5, height)
        var p = Path()
        // Deux boucles
        p.move(to: c)
        p.addCurve(to: c, control1: CGPoint(x: c.x - 58, y: c.y - 44), control2: CGPoint(x: c.x - 64, y: c.y + 4))
        p.move(to: c)
        p.addCurve(to: c, control1: CGPoint(x: c.x + 58, y: c.y - 44), control2: CGPoint(x: c.x + 64, y: c.y + 4))
        // Deux pans
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x - 20, y: c.y + 26))
        p.addLine(to: CGPoint(x: c.x - 6, y: c.y + 20))
        p.closeSubpath()
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x + 20, y: c.y + 26))
        p.addLine(to: CGPoint(x: c.x + 6, y: c.y + 20))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: c.x - 9, y: c.y - 8, width: 18, height: 16))
        return p
    }
}

/// Boîte cadeau en vue isométrique. Fermée, elle attend ; ouverte, le couvercle se soulève et la lumière sort.
struct GiftBox: View {
    let opened: Bool

    private let h: CGFloat = 0.82
    private let t: CGFloat = 0.2
    private let m: CGFloat = 0.07

    private static let outline = Color(hex: 0x0A1830)
    private static let ribbon = Palette.yellow
    private static let ribbonShade = Color(hex: 0xD98E00)

    var body: some View {
        ZStack {
            // Ombre au sol
            IsoFace(corners: [[-0.14, -0.14, 0], [1.14, -0.14, 0], [1.14, 1.14, 0], [-0.14, 1.14, 0]])
                .fill(Palette.blueDark.opacity(0.16))
                .blur(radius: 10)

            // Le corps de la boîte
            face([[0, 0, h], [1, 0, h], [1, 1, h], [0, 1, h]], Self.outline)
            face([[0, 1, 0], [1, 1, 0], [1, 1, h], [0, 1, h]], Palette.blue)
            face([[1, 1, 0], [1, 0, 0], [1, 0, h], [1, 1, h]], Color(hex: 0x132744))
            face([[0.4, 1, 0], [0.6, 1, 0], [0.6, 1, h], [0.4, 1, h]], Self.ribbon)
            face([[1, 0.6, 0], [1, 0.4, 0], [1, 0.4, h], [1, 0.6, h]], Self.ribbonShade)

            // La lumière qui sort de la boîte
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE9B0), Palette.yellow.opacity(0.55), Palette.yellow.opacity(0)],
                                     center: .center, startRadius: 2, endRadius: 78))
                .frame(width: 160, height: 120)
                .offset(y: -48)
                .opacity(opened ? 1 : 0)

            // Le couvercle
            lid
                .offset(x: opened ? 8 : 0, y: opened ? -86 : 0)
                .rotationEffect(.degrees(opened ? -11 : 0))
        }
        .frame(width: 190, height: 200)
        .accessibilityHidden(true)
    }

    private var lid: some View {
        let top = h + t
        return ZStack {
            face([[-m, 1 + m, h], [1 + m, 1 + m, h], [1 + m, 1 + m, top], [-m, 1 + m, top]], Color(hex: 0x27487A))
            face([[1 + m, 1 + m, h], [1 + m, -m, h], [1 + m, -m, top], [1 + m, 1 + m, top]], Color(hex: 0x1A3560))
            face([[-m, -m, top], [1 + m, -m, top], [1 + m, 1 + m, top], [-m, 1 + m, top]], Color(hex: 0x2F5591))
            face([[0.4, 1 + m, h], [0.6, 1 + m, h], [0.6, 1 + m, top], [0.4, 1 + m, top]], Self.ribbon)
            face([[1 + m, 0.6, h], [1 + m, 0.4, h], [1 + m, 0.4, top], [1 + m, 0.6, top]], Self.ribbonShade)
            face([[-m, 0.4, top], [1 + m, 0.4, top], [1 + m, 0.6, top], [-m, 0.6, top]], Self.ribbon)
            face([[0.4, -m, top], [0.6, -m, top], [0.6, 1 + m, top], [0.4, 1 + m, top]], Self.ribbon)
            IsoBow(height: top)
                .fill(Color(hex: 0xFFCB52))
                .overlay(IsoBow(height: top).stroke(Self.outline, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
        }
    }

    private func face(_ corners: [[CGFloat]], _ color: Color) -> some View {
        IsoFace(corners: corners)
            .fill(color)
            .overlay(IsoFace(corners: corners).stroke(Self.outline, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
    }
}

// MARK: - 1 · La surprise, puis le cadeau qui s'ouvre

struct GiftScreen: View {
    let offer: TrialOffer
    let onNext: () -> Void

    @State private var opened = OnboardingDebug.flag("onbGiftOpen")
    @State private var wobble = false
    @State private var twinkle = false

    var body: some View {
        ZStack {
            RaysBackground()
                .opacity(opened ? 1 : 0)

            VStack(spacing: 0) {
                Group {
                    if opened {
                        VStack(spacing: 12) {
                            Text("Before you start, all of Artura is on us.")
                                .font(.figtree(32, .bold))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(dayCountWord(offer.trialDays)) days, everything unlocked. You'll see, it changes everything.")
                                .font(.figtree(17))
                                .foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 36)
                        .transition(.opacity.combined(with: .offset(y: 14)))
                    } else {
                        MascotBubble(mascotSize: 118) {
                            VStack(spacing: 6) {
                                Text("And the best for last…")
                                    .font(.aTitleSmall)
                                    .foregroundStyle(Palette.ink)
                                Text("I have a surprise for you.")
                                    .font(.figtree(17))
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .offset(y: -14)))
                    }
                }
                .enter()

                Spacer(minLength: 20)

                ZStack {
                    GiftBox(opened: opened)
                        .rotationEffect(.degrees(opened ? 0 : (wobble ? 2.2 : -2.2)), anchor: .bottom)
                    sparkle(size: 22, x: -112, y: -70, delay: 0.25)
                    sparkle(size: 16, x: 104, y: -96, delay: 0.4)
                    sparkle(size: 14, x: 118, y: 6, delay: 0.55)
                    sparkle(size: 12, x: -96, y: 30, delay: 0.7)
                }
                .padding(.top, 60)
                .enter(2)

                Spacer(minLength: 20)

                Button(opened ? "Claim my gift" : "Open my surprise") {
                    if opened { onNext() } else { open() }
                }
                .buttonStyle(.primary)

                Text("No commitment. Cancel anytime.")
                    .font(.aSmall)
                    .foregroundStyle(Palette.muted)
                    .frame(height: 36)
                    .opacity(opened ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { wobble = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Sparkle()
            .fill(Palette.yellow)
            .frame(width: size, height: size)
            .scaleEffect(opened ? (twinkle ? 1.15 : 0.8) : 0.1)
            .opacity(opened ? 1 : 0)
            .offset(x: x, y: y)
            .animation(.settle.delay(delay), value: opened)
    }

    private func open() {
        Haptics.heavy()
        withAnimation(.settle) { opened = true }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14 * Double(i)) { Haptics.rigid() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { Haptics.success() }
    }
}

// MARK: - 2 · Aucun engagement

/// Part de disque, pour le cadran.
private struct PieSlice: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Montre de l'essai : une part par jour, la dernière en vert. L'aiguille s'arrête la veille de la fin.
struct TrialClock: View {
    let days: Int
    @State private var run = false

    private var slice: Double { 360 / Double(max(1, days)) }
    private static let outline = Color(hex: 0x0A1830)

    var body: some View {
        ZStack {
            // Anneau et couronne
            Circle().stroke(Palette.yellow, lineWidth: 7).frame(width: 34, height: 34).offset(y: -122)
            RoundedRectangle(cornerRadius: 5)
                .fill(Palette.yellow)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Self.outline, lineWidth: 2))
                .frame(width: 30, height: 22)
                .offset(y: -100)

            Circle().fill(Palette.yellow).overlay(Circle().stroke(Self.outline, lineWidth: 2.5))
                .frame(width: 188, height: 188)
            Circle().fill(.white).frame(width: 152, height: 152)
            PieSlice(start: .degrees(270 - slice), end: .degrees(270))
                .fill(Palette.green)
                .frame(width: 152, height: 152)
            ForEach(0..<max(1, days), id: \.self) { i in
                Rectangle()
                    .fill(Self.outline)
                    .frame(width: 2, height: 76)
                    .offset(y: -38)
                    .rotationEffect(.degrees(Double(i) * slice))
            }
            Circle().stroke(Self.outline, lineWidth: 2.5).frame(width: 152, height: 152)

            // L'aiguille s'arrête au début du dernier jour.
            Capsule()
                .fill(Self.outline)
                .frame(width: 6, height: 62)
                .offset(y: -27)
                .rotationEffect(.degrees(run ? 360 - slice * 0.84 : 0))
            Circle().fill(Palette.orange).overlay(Circle().stroke(Self.outline, lineWidth: 2))
                .frame(width: 16, height: 16)
        }
        .frame(width: 200, height: 260)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).delay(0.7)) { run = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { Haptics.rigid() }
        }
        .accessibilityHidden(true)
    }
}

struct NoCommitmentScreen: View {
    let offer: TrialOffer
    let onNext: () -> Void

    /// « the day before » ressort en gras au milieu de la phrase.
    private var reminderLine: Text {
        Text("You'll get a reminder ")
            + Text("the day before").font(.figtree(19, .bold))
            + Text(" your trial ends.")
    }

    var body: some View {
        ZStack {
            RaysBackground()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("No commitment.")
                        .font(.figtree(36, .bold))
                        .foregroundStyle(Palette.ink)
                        .enter()
                    reminderLine
                        .font(.figtree(19))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(1.5)
                    Text("Plenty of time to explore, and to decide.")
                        .font(.figtree(17))
                        .foregroundStyle(Palette.muted)
                        .enter(3)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 44)

                Spacer(minLength: 16)

                TrialClock(days: offer.trialDays)
                    .enter(4)

                Spacer(minLength: 16)
                Spacer(minLength: 0)

                Button("Try it for \(offer.zeroPrice)") { onNext() }
                    .buttonStyle(.primary)
                Text("No commitment. Cancel anytime.")
                    .font(.aSmall)
                    .foregroundStyle(Palette.muted)
                    .frame(height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
    }
}

// MARK: - 3 · Comment se passe ton essai (paywall)

struct TrialScreen: View {
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var user: UserStore
    let offer: TrialOffer
    /// Le même abonnement avec un essai plus long, proposé si on veut fermer.
    let extendedOffer: TrialOffer?
    let onFinish: () -> Void

    @State private var canClose = false
    @State private var showExitOffer = OnboardingDebug.flag("onbExitOffer")
    @State private var exitOfferSeen = false
    @State private var reminder: Bool?
    /// Étapes de la frise déjà apparues (0 à 3) : elles arrivent une à une, lentement.
    @State private var revealed = 0
    @State private var grow = false

    /// Délai avant que la croix de fermeture apparaisse, en secondes.
    private let closeDelay: Double = 12

    var body: some View {
        VStack(spacing: 0) {
            // La croix : discrète, sans fond, et seulement après un moment.
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.muted.opacity(0.7))
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Close and continue for free")
                .opacity(canClose ? 1 : 0)
                .disabled(!canClose)
                Spacer()
            }
            .padding(.leading, 8)

            // 1 · Le titre et le prix du jour
            VStack(spacing: 10) {
                Text("How your free trial works")
                    .font(.figtree(30, .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    CheckBadge(color: Palette.green, size: 22)
                    Text("\(offer.zeroPrice) today")
                        .font(.figtree(17, .bold))
                        .foregroundStyle(Palette.ink)
                }
            }
            .padding(.horizontal, 24)
            .enter()

            Spacer(minLength: 14)

            // 2 · La frise, compacte
            timeline
                .padding(.horizontal, 24)
                .enter(2)

            reminderRow
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .enter(3)

            Spacer(minLength: 14)

            // 3 · L'action et le prix
            VStack(spacing: 0) {
                if let error = pro.lastError {
                    Text(error)
                        .font(.aCaption)
                        .foregroundStyle(Palette.red)
                        .padding(.bottom, 6)
                }
                Button {
                    buy(offer)
                } label: {
                    if pro.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Text("Start my free trial")
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                Text("\(offer.trialDays) days free, then \(offer.yearlyPrice) per year")
                    .font(.figtree(14))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 12)
                Text("That's \(offer.monthlyPrice) per month")
                    .font(.figtree(14, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 2)

                HStack(spacing: 20) {
                    Button("Restore") { restore() }
                    if let terms = Legal.terms { Link("Terms", destination: terms) }
                    if let privacy = Legal.privacy { Link("Privacy", destination: privacy) }
                }
                .font(.figtree(13))
                .foregroundStyle(Palette.muted)
                .tint(Palette.muted)
                .underline()
                .frame(height: 38)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(closeDelay * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.9)) { canClose = true }
        }
        .onAppear(perform: play)
        .sheet(isPresented: $showExitOffer) {
            if let extendedOffer {
                ExitOfferSheet(pro: pro, offer: extendedOffer, baseDays: offer.trialDays,
                               firstName: user.profile.firstName,
                               onAccept: { buy(extendedOffer) },
                               onDecline: {
                                   showExitOffer = false
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinish() }
                               })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
            }
        }
    }

    /// La frise se déroule lentement : le fil descend, chaque étape apparaît quand il l'atteint.
    private func play() {
        withAnimation(.easeInOut(duration: 3.0).delay(0.7)) { grow = true }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i - 1) * 1.2) {
                withAnimation(.easeOut(duration: 0.8)) { revealed = i }
                Haptics.soft()
            }
        }
    }

    // MARK: Frise

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            timelineRow(1, icon: "lock.open.fill", fill: Palette.blue, tint: .white,
                        title: "Today",
                        text: "All of Artura unlocks, no limits.")
            VStack(alignment: .leading, spacing: 8) {
                timelineRow(2, icon: "bell.fill", fill: Palette.sand, tint: Palette.blue,
                            title: "Day \(max(1, offer.trialDays - 1)) · your reminder",
                            text: "The day before it ends, we'll let you know.")
                notification
                    .padding(.leading, 48)
                    .opacity(revealed >= 2 ? 1 : 0)
            }
            timelineRow(3, icon: "seal.fill", fill: .white, tint: Palette.orange,
                        title: "Day \(offer.trialDays) · Artura Pro",
                        text: "\(offer.yearlyPrice) per year. Cancel before then, in two taps.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            // Le fil qui relie les trois étapes.
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [Palette.blue, Palette.yellow, Palette.orange],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: grow ? max(0, geo.size.height - 76) : 0)
                    .offset(x: 16 + 16.5, y: 16 + 18)
            }
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private func timelineRow(_ step: Int, icon: String, fill: Color, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Palette.blue, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.figtree(16, .bold))
                    .foregroundStyle(Palette.ink)
                Text(text)
                    .font(.figtree(14))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(revealed >= step ? 1 : 0)
        .offset(y: revealed >= step ? 0 : 8)
    }

    /// Aperçu de la notification envoyée la veille de la fin.
    private var notification: some View {
        HStack(spacing: 10) {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 0) {
                Text("Your trial ends tomorrow")
                    .font(.figtree(13, .bold))
                    .foregroundStyle(Palette.ink)
                Text("Come back to your artworks.")
                    .font(.figtree(12))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.sandLight))
    }

    private var reminderRow: some View {
        HStack(spacing: 12) {
            Text(reminder == false ? "Notifications are off. Turn them on in Settings."
                                   : "Remind me the day before it ends")
                .font(.figtree(15, .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if reminder == true {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text("On").font(.figtree(15, .bold))
                }
                .foregroundStyle(Palette.green)
                .transition(.opacity)
            } else if reminder == nil {
                Button("Turn on") { askReminder() }
                    .font(.figtree(15, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Capsule().fill(Palette.blue))
                    .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    // MARK: Actions

    private func askReminder() {
        Task {
            let granted = await Reminder.requestPermission()
            await MainActor.run {
                withAnimation(.gentle) { reminder = granted }
                if granted { Haptics.success() }
            }
        }
    }

    private func close() {
        // Une dernière offre avant de partir, une seule fois.
        if let extendedOffer, !exitOfferSeen, extendedOffer.trialDays > offer.trialDays {
            exitOfferSeen = true
            Haptics.press()
            showExitOffer = true
        } else {
            onFinish()
        }
    }

    private func buy(_ chosen: TrialOffer) {
        guard let product = chosen.product else { return }
        Task {
            let ok = await pro.purchase(product)
            if ok {
                Haptics.success()
                if reminder == true { Reminder.scheduleTrialEnding(trialDays: chosen.trialDays) }
                showExitOffer = false
                onFinish()
            }
        }
    }

    private func restore() {
        Task {
            await pro.restore()
            if pro.isPro {
                Haptics.success()
                onFinish()
            }
        }
    }
}

// MARK: - 4 · « Attends… » : le pass d'une semaine

/// Billet de musée : un rectangle arrondi avec deux encoches, là où on détache le talon.
private struct TicketShape: Shape {
    /// Position des encoches, en part de la hauteur.
    var notch: CGFloat = 0.72

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 11
        let y = rect.minY + rect.height * notch
        return Path(roundedRect: rect, cornerRadius: 22, style: .continuous)
            .subtracting(Path(ellipseIn: CGRect(x: rect.minX - radius, y: y - radius, width: radius * 2, height: radius * 2)))
            .subtracting(Path(ellipseIn: CGRect(x: rect.maxX - radius, y: y - radius, width: radius * 2, height: radius * 2)))
    }
}

struct ExitOfferSheet: View {
    @ObservedObject var pro: ProStore
    let offer: TrialOffer
    /// Durée de l'essai de base, barrée à côté de la nouvelle.
    let baseDays: Int
    let firstName: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var filled = 0
    @State private var stamped = false

    private var extraDays: Int { max(0, offer.trialDays - baseDays) }

    private var title: String {
        if let firstName, !firstName.isEmpty { return "Wait, \(firstName)…" }
        return "Wait…"
    }

    var body: some View {
        VStack(spacing: 0) {
            // La Joconde retient le visiteur : c'est elle qui offre le pass.
            MascotBubble(mascotSize: 100) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.figtree(26, .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Here are \(extraDays) extra days to explore all of Artura.")
                        .font(.figtree(16))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 18)
            .enter()

            Spacer(minLength: 10)

            ticket
                .enter(2)

            Spacer(minLength: 10)

            VStack(spacing: 4) {
                if let error = pro.lastError {
                    Text(error).font(.aCaption).foregroundStyle(Palette.red)
                }
                Button {
                    onAccept()
                } label: {
                    if pro.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Get my \(offer.trialDays)-day pass")
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                Button("No thanks") {
                    Haptics.tap()
                    onDecline()
                }
                .font(.figtree(15, .medium))
                .foregroundStyle(Palette.muted)
                .underline()
                .frame(height: 44)

                Text("\(offer.zeroPrice) today, then \(offer.yearlyPrice) per year after \(offer.trialDays) days.")
                    .font(.aCaption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .onAppear {
            Haptics.soft()
            // Les jours se remplissent un à un : d'abord l'essai, puis les jours offerts.
            for i in 1...max(1, offer.trialDays) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.14) {
                    withAnimation(.easeOut(duration: 0.25)) { filled = i }
                    if i > baseDays { Haptics.rigid() } else { Haptics.whisper() }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(offer.trialDays) * 0.14) {
                withAnimation(.settle) { stamped = true }
                Haptics.heavy()
            }
        }
    }

    /// Le pass, dessiné comme un billet d'entrée de musée.
    private var ticket: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ARTURA PRO · VISITOR PASS")
                        .font(.figtree(11, .bold))
                        .tracking(2)
                        .foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(offer.trialDays) days free")
                        .font(.figtree(30, .bold))
                        .foregroundStyle(Palette.ink)
                    Text("\(baseDays) days")
                        .font(.figtree(16, .medium))
                        .foregroundStyle(Palette.muted)
                        .strikethrough()
                }
                HStack(spacing: 5) {
                    ForEach(0..<max(1, offer.trialDays), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 7)
                            .fill(i < filled ? (i < baseDays ? Palette.blue : Palette.green) : Palette.line)
                            .frame(height: 20)
                    }
                }
                HStack {
                    Text("Days 1–\(baseDays): your trial")
                        .font(.figtree(13, .medium)).foregroundStyle(Palette.blue)
                    Spacer(minLength: 8)
                    Text("Days \(baseDays + 1)–\(offer.trialDays): on us")
                        .font(.figtree(13, .bold)).foregroundStyle(Palette.green)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // La ligne de découpe du talon
            Line()
                .stroke(Palette.lip, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .frame(height: 1.5)
                .padding(.horizontal, 18)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Full access")
                        .font(.figtree(15, .bold)).foregroundStyle(Palette.ink)
                    Text("Lessons, games and movements")
                        .font(.figtree(13)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                // Le tampon « offert »
                Text("+ \(extraDays) DAYS FREE")
                    .font(.figtree(11, .bold))
                    .tracking(0.5)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Palette.green)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.green, lineWidth: 2))
                    .rotationEffect(.degrees(-6))
                    .scaleEffect(stamped ? 1 : 1.6)
                    .opacity(stamped ? 1 : 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(TicketShape().fill(.white).shadow(color: Palette.blueDark.opacity(0.12), radius: 16, y: 8))
        .overlay(TicketShape().stroke(Palette.blue, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visitor pass: \(offer.trialDays) days free instead of \(baseDays)")
    }
}

/// Trait horizontal, pour les pointillés.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Profile paywall (yearly or monthly choice)

struct PaywallScreen: View {
    @EnvironmentObject private var pro: ProStore
    let onClose: () -> Void
    @State private var yearlySelected = true

    private let benefits = [
        "All games, no daily limit",
        "All paths and their lessons",
        "Stories in audio",
        "No ads"
    ]

    private var selectedProduct: Product? { yearlySelected ? pro.yearly : pro.monthly }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ArtImage(name: "ill_premium", anchor: UnitPoint(x: 0.5, y: 0.4))
                    .frame(height: 240)
                    .clipShape(ArcHeaderShape())
                    .ignoresSafeArea(edges: .top)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Close and continue for free")
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 14) {
                Text("Start your 3 days of Artura Pro")
                    .font(.aTitleSmall).foregroundStyle(Palette.ink).multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(benefits.enumerated()), id: \.offset) { i, benefit in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.green)
                            Text(benefit).font(.figtree(15)).foregroundStyle(Palette.ink)
                        }
                        .appearUp(0.06 * Double(i))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

                planRow(title: "Yearly", price: pro.yearly.map { "\($0.displayPrice) per year" }, badge: "3 days free", selected: yearlySelected) {
                    yearlySelected = true
                }
                planRow(title: "Monthly", price: pro.monthly.map { "\($0.displayPrice) per month" }, badge: nil, selected: !yearlySelected) {
                    yearlySelected = false
                }
                if let error = pro.lastError {
                    Text(error).font(.aCaption).foregroundStyle(Palette.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, -20)

            Spacer(minLength: 12)

            VStack(spacing: 2) {
                Button {
                    purchase()
                } label: {
                    if pro.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start free trial")
                    }
                }
                .buttonStyle(.primary)
                .disabled(selectedProduct == nil || pro.isPurchasing)
                .opacity(selectedProduct == nil ? 0.4 : 1)

                TextLinkButton(title: "Not now", action: onClose)
                Button("Restore purchases") {
                    Task {
                        await pro.restore()
                        if pro.isPro {
                            Haptics.success()
                            onClose()
                        }
                    }
                }
                .font(.figtree(12))
                .foregroundStyle(Palette.muted)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .task {
            if pro.products.isEmpty { await pro.loadProducts() }
        }
    }

    private func planRow(title: String, price: String?, badge: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if let badge { TagPill(text: badge) }
                    Text(title).font(.bodyStrong).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 8)
                Text(price ?? "Price unavailable").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                if selected { CheckBadge().transition(.scale) }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: badge == nil ? 60 : 72)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.sandLight : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        Task {
            let ok = await pro.purchase(product)
            if ok {
                Haptics.success()
                if await Reminder.requestPermission() {
                    Reminder.scheduleTrialEnding()
                }
                onClose()
            }
        }
    }
}
