import SwiftUI
import StoreKit

// MARK: Free trial · 1

struct TrialIntroScreen: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_premium", onNext: onNext, secondaryTitle: "No thanks", onSecondary: onSkip) {
            TagPill(text: "3 days free").appearUp(0.1)
            Text("We want you to try Artura Pro for free")
                .font(.figtree(30, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Three days to explore everything. Nothing to pay today.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.3)
        }
    }
}

// MARK: Free trial · 2 (timeline)

struct TrialTimelineScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var grow = false

    private let steps: [(String, String, String, String)] = [
        ("lock.open.fill", "Today", "Everything's unlocked", "Unlimited games, every path, and audio stories."),
        ("bell.fill", "Day 2", "We'll remind you", "You'll get a notification that your trial ends the next day."),
        ("star.fill", "Day 3", "Your subscription starts", "Unless you cancel before then. If you do, you pay nothing.")
    ]

    var body: some View {
        OnbScaffold(onBack: onBack, title: "How your free trial works", onNext: onNext) {
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
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * Double(i) + 0.2) { Haptics.rigid() }
            }
        }
    }
}

// MARK: Free trial · 3 (notification)

struct TrialNotifScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var dropped = false

    var body: some View {
        OnbScaffold(onBack: onBack, title: "We'll notify you 1 day before it ends",
                    subtitle: "No surprises. You decide with all the facts.", onNext: onNext) {
            ZStack(alignment: .top) {
                ArtImage(name: "ill_rappel", anchor: UnitPoint(x: 0.5, y: 0.8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Artura").font(.figtree(12, .semibold)).foregroundStyle(Palette.blueText)
                        Spacer()
                        Text("Day 2 · 9:00 AM").font(.figtree(12)).foregroundStyle(Palette.muted)
                    }
                    Text("Your free trial ends tomorrow").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                    Text("Keep going with Artura Pro or cancel in one tap.")
                        .font(.aSmall).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: .black.opacity(0.18), radius: 16, y: 8))
                .padding(20)
                .offset(y: dropped ? 0 : -60)
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
        "All the games, no daily limit",
        "Every path and its lessons",
        "Audio versions of the stories",
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
                Text(price ?? "Price unavailable").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
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
