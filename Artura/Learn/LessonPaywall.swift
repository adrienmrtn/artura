import SwiftUI
import StoreKit

/// Paywall shown inside a lesson, built around the painting being read.
/// Used when a free reader reaches the quiz, or goes on with a second lesson in the same day.
struct LessonPaywall: View {
    @EnvironmentObject private var pro: ProStore
    let artwork: Artwork
    let title: String
    let subtitle: String
    /// Label of the way out ("Not now", "Leave this lesson"…).
    let closeTitle: String
    let onClose: () -> Void
    /// Called once the subscription is active.
    let onUnlocked: () -> Void

    private let benefits = [
        "Every lesson, as many as you like each day",
        "The quiz at the end of each lesson",
        "All games, no daily limit"
    ]

    private var priceLine: String? {
        guard let yearly = pro.yearly else { return nil }
        if let offer = TrialOffer(yearly) {
            return "\(offer.trialDays) days free, then \(offer.yearlyPrice) per year"
        }
        return "\(yearly.displayPrice) per year"
    }

    var body: some View {
        VStack(spacing: 0) {
            // The painting of the lesson, under the arc
            ArtImage(name: artwork.image, anchor: artwork.focusPoint)
                .frame(height: 300)
                .clipShape(ArcHeaderShape())
                .overlay(alignment: .bottom) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Palette.blue))
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .offset(y: -12)
                }
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                Text(title)
                    .font(.figtree(28, .bold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.aBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, -24)
            .appearUp(0.05)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(benefits.enumerated()), id: \.offset) { i, benefit in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.green)
                        Text(benefit).font(.figtree(15)).foregroundStyle(Palette.ink)
                    }
                    .appearUp(0.1 + 0.06 * Double(i))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer(minLength: 12)

            VStack(spacing: 2) {
                if let error = pro.lastError {
                    Text(error).font(.aCaption).foregroundStyle(Palette.red)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                }
                Button {
                    purchase()
                } label: {
                    if pro.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(pro.yearly.flatMap { TrialOffer($0) } == nil ? "Unlock Artura Pro" : "Start free trial")
                    }
                }
                .buttonStyle(.primary)
                .disabled(pro.yearly == nil || pro.isPurchasing)
                .opacity(pro.yearly == nil ? 0.4 : 1)

                Text(priceLine ?? "Price unavailable")
                    .font(.figtree(14))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 8)

                TextLinkButton(title: closeTitle, action: onClose)
                Button("Restore purchases") {
                    Task {
                        await pro.restore()
                        if pro.isPro {
                            Haptics.success()
                            onUnlocked()
                        }
                    }
                }
                .font(.figtree(12))
                .foregroundStyle(Palette.muted)
                .frame(minHeight: 36)
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

    private func purchase() {
        guard let product = pro.yearly else { return }
        Task {
            if await pro.purchase(product) {
                Haptics.success()
                onUnlocked()
            }
        }
    }
}
