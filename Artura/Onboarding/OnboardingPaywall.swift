import SwiftUI
import StoreKit

// MARK: Essai gratuit · 1

struct TrialIntroScreen: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_premium", onNext: onNext, secondaryTitle: "Non merci", onSecondary: onSkip) {
            TagPill(text: "3 jours offerts").appearUp(0.1)
            Text("On veut que tu essaies Artura Pro gratuitement")
                .font(.figtree(30, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Trois jours pour tout découvrir. Rien à payer aujourd'hui.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.3)
        }
    }
}

// MARK: Essai gratuit · 2 (frise)

struct TrialTimelineScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var grow = false

    private let steps: [(String, String, String, String)] = [
        ("lock.open.fill", "Aujourd'hui", "Tout est débloqué", "Jeux sans limite, tous les parcours, les histoires en audio."),
        ("bell.fill", "Jour 2", "On te prévient", "Une notification te rappelle que l'essai se termine le lendemain."),
        ("star.fill", "Jour 3", "Ton abonnement commence", "Sauf si tu annules avant. Dans ce cas, tu ne paies rien.")
    ]

    var body: some View {
        OnbScaffold(onBack: onBack, title: "Comment se passe ton essai gratuit", onNext: onNext) {
            ZStack(alignment: .topLeading) {
                Capsule().fill(Palette.line).frame(width: 6, height: 300).offset(x: 21, y: 22)
                Capsule().fill(Palette.blue).frame(width: 6, height: grow ? 90 : 0).offset(x: 21, y: 22)
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: step.0)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(i == 0 ? .white : Palette.ink)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(i == 0 ? Palette.blue : (i == 1 ? Palette.yellow : Palette.card)))
                                .background(Circle().fill(.white).frame(width: 56, height: 56))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.1).font(.figtree(13, .semibold))
                                    .foregroundStyle(i == 0 ? Palette.blueText : Palette.muted)
                                Text(step.2).font(.aCardTitle).foregroundStyle(Palette.ink)
                                Text(step.3).font(.aSmall).foregroundStyle(Palette.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .appearUp(0.15 * Double(i + 1))
                    }
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.3)) { grow = true }
        }
    }
}

// MARK: Essai gratuit · 3 (notification)

struct TrialNotifScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var dropped = false

    var body: some View {
        OnbScaffold(onBack: onBack, title: "On t'envoie une notification 1 jour avant la fin",
                    subtitle: "Pas de mauvaise surprise : tu décides en connaissance de cause.", onNext: onNext) {
            ZStack(alignment: .top) {
                ArtImage(name: "ill_rappel", anchor: UnitPoint(x: 0.5, y: 0.8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Artura").font(.figtree(12, .semibold)).foregroundStyle(Palette.blueText)
                        Spacer()
                        Text("Jour 2 · 9 h 00").font(.figtree(12)).foregroundStyle(Palette.muted)
                    }
                    Text("Ton essai gratuit se termine demain").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                    Text("Tu peux continuer avec Artura Pro ou annuler en un geste.")
                        .font(.aSmall).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: .black.opacity(0.18), radius: 16, y: 8))
                .padding(20)
                .offset(y: dropped ? 0 : -160)
                .opacity(dropped ? 1 : 0)
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.bouncy) { dropped = true }
                Haptics.heavy()
            }
        }
    }
}

// MARK: Paywall

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
        .background(Color.white)
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
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.blueSelected : Palette.card))
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
