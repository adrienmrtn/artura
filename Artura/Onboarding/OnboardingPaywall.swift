import SwiftUI
import StoreKit

// End of onboarding: the surprise, the gift (free trial), "no commitment",
// how the trial works, then the last-minute offer if the user wants to leave.

enum Legal {
    /// Terms of Use: Apple's standard EULA, to be replaced if the app has its own.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Privacy Policy: to be filled in before release.
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

// MARK: - Isometric drawing (gift box)

/// Projects a point (x, y, z) of a unit cube onto the screen, in isometric view.
/// The corner closest to the viewer, (1, 1, 0), lands at the bottom center of the frame.
private struct Iso {
    let rect: CGRect
    var unit: CGFloat { rect.width / 1.732 }

    func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: rect.midX + (x - y) * 0.866 * unit,
                y: rect.maxY - unit + (x + y) * 0.5 * unit - z * unit)
    }
}

/// A flat face defined by its corners in cube space.
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

/// The ribbon bow, sitting at the center of the lid.
private struct IsoBow: Shape {
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = Iso(rect: rect).point(0.5, 0.5, height)
        var p = Path()
        // Two loops
        p.move(to: c)
        p.addCurve(to: c, control1: CGPoint(x: c.x - 58, y: c.y - 44), control2: CGPoint(x: c.x - 64, y: c.y + 4))
        p.move(to: c)
        p.addCurve(to: c, control1: CGPoint(x: c.x + 58, y: c.y - 44), control2: CGPoint(x: c.x + 64, y: c.y + 4))
        // Two tails
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

/// Gift box in isometric view. Closed, it waits; opened, the lid lifts and light pours out.
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
            // Ground shadow
            IsoFace(corners: [[-0.14, -0.14, 0], [1.14, -0.14, 0], [1.14, 1.14, 0], [-0.14, 1.14, 0]])
                .fill(Palette.blueDark.opacity(0.16))
                .blur(radius: 10)

            // The body of the box
            face([[0, 0, h], [1, 0, h], [1, 1, h], [0, 1, h]], Self.outline)
            face([[0, 1, 0], [1, 1, 0], [1, 1, h], [0, 1, h]], Palette.blue)
            face([[1, 1, 0], [1, 0, 0], [1, 0, h], [1, 1, h]], Color(hex: 0x132744))
            face([[0.4, 1, 0], [0.6, 1, 0], [0.6, 1, h], [0.4, 1, h]], Self.ribbon)
            face([[1, 0.6, 0], [1, 0.4, 0], [1, 0.4, h], [1, 0.6, h]], Self.ribbonShade)

            // The light coming out of the box
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE9B0), Palette.yellow.opacity(0.55), Palette.yellow.opacity(0)],
                                     center: .center, startRadius: 2, endRadius: 78))
                .frame(width: 160, height: 120)
                .offset(y: -48)
                .opacity(opened ? 1 : 0)

            // The lid
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

// MARK: - 1 · The surprise, then the gift opens

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
                                Text("We saved the best for last…")
                                    .font(.aTitleSmall)
                                    .foregroundStyle(Palette.ink)
                                Text("We have a surprise for you.")
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

// MARK: - 2 · No commitment

/// Pie slice, for the dial.
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

/// Trial watch: one slice per day, the last one in green. The hand stops the day before the end.
struct TrialClock: View {
    let days: Int
    @State private var run = false

    private var slice: Double { 360 / Double(max(1, days)) }
    private static let outline = Color(hex: 0x0A1830)

    var body: some View {
        ZStack {
            // Ring and crown
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

            // The hand stops at the start of the last day.
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

    /// "the day before" stands out in bold mid-sentence.
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
                    Text("Your discoveries, and time to decide.")
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

                Button("Try for \(offer.zeroPrice)") { onNext() }
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

// MARK: - 3 · How your trial works (paywall)

struct TrialScreen: View {
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var user: UserStore
    let offer: TrialOffer
    /// The same subscription with a longer trial, offered if the user tries to close.
    let extendedOffer: TrialOffer?
    let onFinish: () -> Void

    @State private var canClose = false
    @State private var showExitOffer = OnboardingDebug.flag("onbExitOffer")
    @State private var exitOfferSeen = false
    @State private var reminder: Bool?
    @State private var grow = false

    /// Delay before the close button appears, in seconds.
    private let closeDelay: Double = 8

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("How your trial works")
                            .font(.figtree(28, .bold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 36)
                        HStack(spacing: 8) {
                            CheckBadge(color: Palette.green, size: 22)
                            Text("\(offer.zeroPrice) today")
                                .font(.figtree(17, .bold))
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .enter()

                    timeline
                        .enter(2)

                    reminderRow
                        .enter(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 6) {
                if let error = pro.lastError {
                    Text(error).font(.aCaption).foregroundStyle(Palette.red)
                }
                Button {
                    buy(offer)
                } label: {
                    if pro.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Text("Start my trial")
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                VStack(spacing: 2) {
                    Text("\(offer.trialDays) day\(offer.trialDays == 1 ? "" : "s") of unlimited access, then \(offer.yearlyPrice) per year")
                        .font(.aSmall).foregroundStyle(Palette.muted)
                    Text("That's just \(offer.monthlyPrice) per month")
                        .font(.figtree(14, .bold)).foregroundStyle(Palette.ink)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 4)

                HStack(spacing: 18) {
                    Button("Restore") { restore() }
                    if let terms = Legal.terms { Link("Terms", destination: terms) }
                    if let privacy = Legal.privacy { Link("Privacy", destination: privacy) }
                }
                .font(.figtree(13))
                .foregroundStyle(Palette.muted)
                .tint(Palette.muted)
                .underline()
                .frame(height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .overlay(alignment: .topLeading) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close and continue for free")
            .opacity(canClose ? 1 : 0)
            .disabled(!canClose)
            .padding(.leading, 14)
            .padding(.top, 6)
        }
        .task {
            // The close button only appears after a few seconds of reading.
            try? await Task.sleep(nanoseconds: UInt64(closeDelay * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.4)) { canClose = true }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.5)) { grow = true }
        }
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

    // MARK: Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            timelineRow(icon: "lock.open.fill", fill: Palette.blue, tint: .white,
                        title: "Today",
                        text: "All of Artura unlocks: lessons, games, and paths, no limits.")
            VStack(alignment: .leading, spacing: 10) {
                timelineRow(icon: "bell.fill", fill: Palette.sand, tint: Palette.blue,
                            title: "Day \(max(1, offer.trialDays - 1)) · your reminder",
                            text: "The day before it ends, we'll let you know.")
                notification
                    .padding(.leading, 62)
            }
            timelineRow(icon: "seal.fill", fill: .white, tint: Palette.orange,
                        title: "Day \(offer.trialDays) · Artura Pro",
                        text: "Your trial becomes Artura Pro at \(offer.yearlyPrice) per year. Cancel before then in two taps if you like.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            // The thread linking the three steps, from blue to terracotta.
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [Palette.blue, Palette.yellow, Palette.orange],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: grow ? max(0, geo.size.height - 92) : 0)
                    .offset(x: 16 + 22, y: 16 + 24)
            }
        }
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private func timelineRow(icon: String, fill: Color, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Palette.blue, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.figtree(18, .bold)).foregroundStyle(Palette.ink)
                Text(text).font(.figtree(15)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Preview of the notification sent the day before the end.
    private var notification: some View {
        HStack(spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text("Your free trial ends tomorrow")
                    .font(.figtree(14, .bold)).foregroundStyle(Palette.ink)
                Text("Come back to the artworks you've discovered.")
                    .font(.figtree(13)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.sandLight))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.sand, lineWidth: 1))
    }

    private var reminderRow: some View {
        HStack(spacing: 12) {
            Text(reminder == false ? "Notifications are off. You can turn them on in Settings."
                                   : "Get a reminder the day before it ends")
                .font(.figtree(16, .medium))
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
                    .frame(height: 40)
                    .background(Capsule().fill(Palette.blue))
                    .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
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
        // One last offer before leaving, shown only once.
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

// MARK: - 4 · "Wait…": the last-minute offer

/// Sealed envelope, slightly tilted.
private struct OfferEnvelope: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: Palette.blueDark.opacity(0.14), radius: 14, y: 8)
            // The folds of the flap
            GeometryReader { geo in
                Path { p in
                    let w = geo.size.width
                    let h = geo.size.height
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w / 2, y: h * 0.56))
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.44))
                    p.move(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.44))
                }
                .stroke(Palette.lip, lineWidth: 1.5)
            }
            RoundedRectangle(cornerRadius: 12).stroke(Palette.blue, lineWidth: 1.5)
            // The wax seal
            Text("A")
                .font(.figtree(24, .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Palette.orange))
                .overlay(Circle().stroke(Palette.blueDark, lineWidth: 1.5))
                .scaleEffect(pulse ? 1.06 : 1)
                .offset(y: 12)
        }
        .frame(width: 236, height: 148)
        .rotationEffect(.degrees(-3))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

struct ExitOfferSheet: View {
    @ObservedObject var pro: ProStore
    let offer: TrialOffer
    /// Length of the base trial, struck through next to the new one.
    let baseDays: Int
    let firstName: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var filled = 0

    private var extraDays: Int { max(0, offer.trialDays - baseDays) }

    private var title: String {
        if let firstName, !firstName.isEmpty { return "Wait, \(firstName)…" }
        return "Wait…"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.figtree(34, .bold))
                    .foregroundStyle(Palette.ink)
                Text("Before you go, we have one last thing for you.")
                    .font(.figtree(17))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 36)
            .enter()

            Spacer(minLength: 12)

            OfferEnvelope()
                .enter(2)

            Spacer(minLength: 12)

            Text("YOUR EXCLUSIVE OFFER")
                .font(.figtree(12, .bold))
                .tracking(3)
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 14)
                .enter(3)

            offerCard
                .enter(4)

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
                        Text("Claim this offer")
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                Button("No thanks, I'll pass") {
                    Haptics.tap()
                    onDecline()
                }
                .font(.figtree(15, .medium))
                .foregroundStyle(Palette.muted)
                .underline()
                .frame(height: 44)

                Text("\(offer.zeroPrice) today, then \(offer.yearlyPrice) per year after \(offer.trialDays) day\(offer.trialDays == 1 ? "" : "s").")
                    .font(.aCaption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .onAppear {
            Haptics.soft()
            // Days fill in one by one: first the trial, then the free extra days.
            for i in 1...max(1, offer.trialDays) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.12) {
                    withAnimation(.easeOut(duration: 0.25)) { filled = i }
                    if i > baseDays { Haptics.rigid() } else { Haptics.whisper() }
                }
            }
        }
    }

    private var offerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(baseDays) day\(baseDays == 1 ? "" : "s")")
                    .font(.figtree(17, .medium))
                    .foregroundStyle(Palette.muted)
                    .strikethrough()
                Text("\(offer.trialDays) day\(offer.trialDays == 1 ? "" : "s") free")
                    .font(.figtree(28, .bold))
                    .foregroundStyle(Palette.ink)
            }
            HStack(spacing: 5) {
                ForEach(0..<max(1, offer.trialDays), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(i < filled ? (i < baseDays ? Palette.blue : Palette.green) : Palette.line)
                        .frame(height: 22)
                }
            }
            HStack {
                Text("Days 1–\(baseDays): your trial")
                    .font(.figtree(13, .medium)).foregroundStyle(Palette.blue)
                Spacer(minLength: 8)
                Text("Days \(baseDays + 1)–\(offer.trialDays): free")
                    .font(.figtree(13, .bold)).foregroundStyle(Palette.green)
            }
            Text(offer.trialDays == 7 ? "A full week to try everything." : "\(offer.trialDays) day\(offer.trialDays == 1 ? "" : "s") to try everything.")
                .font(.figtree(16))
                .italic()
                .foregroundStyle(Palette.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.green, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            Text("+ \(extraDays) day\(extraDays == 1 ? "" : "s") free")
                .font(.figtree(13, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Palette.green))
                .offset(x: -16, y: -14)
        }
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
