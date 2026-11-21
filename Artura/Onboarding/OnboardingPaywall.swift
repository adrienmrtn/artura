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
    case 3: return "Trois"
    case 7: return "Sept"
    case 14: return "Quatorze"
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
    private static let ribbonShade = Color(hex: 0xC98A22)

    var body: some View {
        ZStack {
            // Ombre au sol
            IsoFace(corners: [[-0.14, -0.14, 0], [1.14, -0.14, 0], [1.14, 1.14, 0], [-0.14, 1.14, 0]])
                .fill(Palette.navyDark.opacity(0.16))
                .blur(radius: 10)

            // Le corps de la boîte
            face([[0, 0, h], [1, 0, h], [1, 1, h], [0, 1, h]], Self.outline)
            face([[0, 1, 0], [1, 1, 0], [1, 1, h], [0, 1, h]], Palette.navy)
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
                .fill(Self.ribbon)
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
                            Text("Avant de commencer, on t'offre Artura en entier.")
                                .font(.serif(32, .bold))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(dayCountWord(offer.trialDays)) jours, tout ouvert. Tu verras, ça change tout.")
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
                                Text("Et le meilleur pour la fin…")
                                    .font(.aTitleSmall)
                                    .foregroundStyle(Palette.ink)
                                Text("On a une surprise pour toi.")
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

                Button(opened ? "J'en profite" : "Ouvrir ma surprise") {
                    if opened { onNext() } else { open() }
                }
                .buttonStyle(.primary)

                Text("Sans engagement. Annulation libre.")
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
            Circle().fill(Palette.card).frame(width: 152, height: 152)
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

            // L'aiguille
            Capsule()
                .fill(Self.outline)
                .frame(width: 5, height: 60)
                .offset(y: -26)
                .rotationEffect(.degrees(run ? 360 - slice : 0))
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

    /// « la veille » ressort en gras au milieu de la phrase.
    private var reminderLine: Text {
        Text("Tu reçois un rappel ")
            + Text("la veille").font(.figtree(19, .bold))
            + Text(" de la fin de l'essai.")
    }

    var body: some View {
        ZStack {
            RaysBackground()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Aucun engagement.")
                        .font(.serif(36, .bold))
                        .foregroundStyle(Palette.ink)
                        .enter()
                    reminderLine
                        .font(.figtree(19))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .enter(1.5)
                    Text("Tes découvertes, et le temps de décider.")
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

                Button("Essayer pour \(offer.zeroPrice)") { onNext() }
                    .buttonStyle(.primary)
                Text("Sans engagement. Annulation libre.")
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
    @State private var grow = false

    /// Délai avant que la croix de fermeture apparaisse, en secondes.
    private let closeDelay: Double = 8

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.card))
                        .overlay(Circle().stroke(Palette.line, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Fermer et continuer gratuitement")
                .opacity(canClose ? 1 : 0)
                .disabled(!canClose)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Text("Comment se passe ton essai ?")
                            .font(.serif(32, .bold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            CheckBadge(color: Palette.green, size: 22)
                            Text("\(offer.zeroPrice) aujourd'hui")
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
                .padding(.top, 4)
                .padding(.bottom, 12)
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
                            Text("Commencer mon essai")
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                VStack(spacing: 2) {
                    Text("\(offer.trialDays) jours d'accès illimité, puis \(offer.yearlyPrice) par an")
                        .font(.aSmall).foregroundStyle(Palette.muted)
                    Text("Soit \(offer.monthlyPrice) par mois")
                        .font(.figtree(14, .bold)).foregroundStyle(Palette.ink)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 4)

                HStack(spacing: 18) {
                    Button("Restaurer") { restore() }
                    if let terms = Legal.terms { Link("Conditions", destination: terms) }
                    if let privacy = Legal.privacy { Link("Confidentialité", destination: privacy) }
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
        .task {
            // La croix n'apparaît qu'après quelques secondes de lecture.
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

    // MARK: Frise

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 22) {
            timelineRow(icon: "lock.open.fill", fill: Palette.navy, tint: .white,
                        title: "Aujourd'hui",
                        text: "Tout Artura s'ouvre : cours, jeux et parcours, sans limite.")
            VStack(alignment: .leading, spacing: 12) {
                timelineRow(icon: "bell.fill", fill: Palette.sand, tint: Palette.navy,
                            title: "Jour \(max(1, offer.trialDays - 1)) · ton rappel",
                            text: "La veille de la fin, on te prévient.")
                notification
                    .padding(.leading, 62)
            }
            timelineRow(icon: "seal.fill", fill: Palette.card, tint: Palette.orange,
                        title: "Jour \(offer.trialDays) · Artura Pro",
                        text: "L'essai devient Artura Pro à \(offer.yearlyPrice) par an. Annule avant, en deux gestes, si tu veux.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            // Le fil qui relie les trois étapes, du bleu vers la terre cuite.
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [Palette.navy, Palette.yellow, Palette.orange],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: grow ? max(0, geo.size.height - 96) : 0)
                    .offset(x: 18 + 22, y: 18 + 24)
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
                .overlay(Circle().stroke(Palette.navy, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.figtree(18, .bold)).foregroundStyle(Palette.ink)
                Text(text).font(.figtree(15)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Aperçu de la notification envoyée la veille de la fin.
    private var notification: some View {
        HStack(spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ton essai se termine demain")
                    .font(.figtree(14, .bold)).foregroundStyle(Palette.ink)
                Text("Reviens voir les œuvres que tu as découvertes.")
                    .font(.figtree(13)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.sandLight))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.sand, lineWidth: 1))
    }

    private var reminderRow: some View {
        HStack(spacing: 12) {
            Text(reminder == false ? "Notifications refusées : tu peux les activer dans Réglages."
                                   : "Recevoir un rappel la veille de la fin")
                .font(.figtree(16, .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if reminder == true {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text("Activé").font(.figtree(15, .bold))
                }
                .foregroundStyle(Palette.green)
                .transition(.opacity)
            } else if reminder == nil {
                Button("Activer") { askReminder() }
                    .font(.figtree(15, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Capsule().fill(Palette.navy))
                    .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 68)
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

// MARK: - 4 · « Attends… » : l'offre de dernière minute

/// Enveloppe cachetée, légèrement penchée.
private struct OfferEnvelope: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Palette.card)
                .shadow(color: Palette.navyDark.opacity(0.14), radius: 14, y: 8)
            // Les plis du rabat
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
            RoundedRectangle(cornerRadius: 12).stroke(Palette.navy, lineWidth: 1.5)
            // Le cachet de cire
            Text("A")
                .font(.serif(24, .bold))
                .foregroundStyle(Palette.card)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Palette.orange))
                .overlay(Circle().stroke(Palette.navyDark, lineWidth: 1.5))
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
    /// Durée de l'essai de base, barrée à côté de la nouvelle.
    let baseDays: Int
    let firstName: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var filled = 0

    private var extraDays: Int { max(0, offer.trialDays - baseDays) }

    private var title: String {
        if let firstName, !firstName.isEmpty { return "Attends, \(firstName)…" }
        return "Attends…"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.serif(34, .bold))
                    .foregroundStyle(Palette.ink)
                Text("Avant de partir, on a une dernière chose pour toi.")
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

            Text("TON OFFRE EXCLUSIVE")
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
                        Text("Profiter de cette offre")
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.isPurchasing)

                Button("Non merci, je quitte") {
                    Haptics.tap()
                    onDecline()
                }
                .font(.figtree(15, .medium))
                .foregroundStyle(Palette.muted)
                .underline()
                .frame(height: 44)

                Text("\(offer.zeroPrice) aujourd'hui, puis \(offer.yearlyPrice) par an après \(offer.trialDays) jours.")
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
            // Les jours se remplissent un à un : d'abord l'essai, puis les jours offerts.
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
                Text("\(baseDays) jours")
                    .font(.figtree(17, .medium))
                    .foregroundStyle(Palette.muted)
                    .strikethrough()
                Text("\(offer.trialDays) jours gratuits")
                    .font(.serif(28, .bold))
                    .foregroundStyle(Palette.ink)
            }
            HStack(spacing: 5) {
                ForEach(0..<max(1, offer.trialDays), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 7)
                        .fill(i < filled ? (i < baseDays ? Palette.navy : Palette.green) : Palette.line)
                        .frame(height: 22)
                }
            }
            HStack {
                Text("J1 à J\(baseDays) : ton essai")
                    .font(.figtree(13, .medium)).foregroundStyle(Palette.navy)
                Spacer(minLength: 8)
                Text("J\(baseDays + 1) à J\(offer.trialDays) : offerts")
                    .font(.figtree(13, .bold)).foregroundStyle(Palette.green)
            }
            Text(offer.trialDays == 7 ? "Une semaine entière pour tout essayer." : "\(offer.trialDays) jours pour tout essayer.")
                .font(.serif(16, .regular))
                .italic()
                .foregroundStyle(Palette.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.green, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            Text("+ \(extraDays) jours offerts")
                .font(.figtree(13, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Palette.green))
                .offset(x: -16, y: -14)
        }
    }
}

// MARK: - Paywall du profil (choix annuel ou mensuel)

struct PaywallScreen: View {
    @EnvironmentObject private var pro: ProStore
    let onClose: () -> Void
    @State private var yearlySelected = true

    private let benefits = [
        "Tous les jeux, sans limite quotidienne",
        "Tous les parcours et leurs leçons",
        "Les histoires en version audio",
        "Aucune publicité"
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
                .accessibilityLabel("Fermer et continuer gratuitement")
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 14) {
                Text("Démarre tes 3 jours d'Artura Pro")
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

                planRow(title: "Annuel", price: pro.yearly.map { "\($0.displayPrice) / an" }, badge: "3 jours gratuits", selected: yearlySelected) {
                    yearlySelected = true
                }
                planRow(title: "Mensuel", price: pro.monthly.map { "\($0.displayPrice) / mois" }, badge: nil, selected: !yearlySelected) {
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
                        Text("Commencer l'essai gratuit")
                    }
                }
                .buttonStyle(.primary)
                .disabled(selectedProduct == nil || pro.isPurchasing)
                .opacity(selectedProduct == nil ? 0.4 : 1)

                TextLinkButton(title: "Plus tard", action: onClose)
                Button("Restaurer mes achats") {
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
                Text(price ?? "Prix indisponible").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                if selected { CheckBadge().transition(.scale) }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: badge == nil ? 60 : 72)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.sandLight : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.navy : .clear, lineWidth: 2))
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
