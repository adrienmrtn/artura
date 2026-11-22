import SwiftUI

/// Shows the "Artwork of the day" widget in its three sizes, and how to add it to the Home Screen.
struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let artwork = DailyCatalog.artwork()

    private let steps: [(symbol: String, text: String)] = [
        ("hand.tap.fill", L("Touch and hold an empty area of your Home Screen.")),
        ("plus.circle.fill", L("Tap Edit, then Add Widget.")),
        ("magnifyingglass", L("Search for Artura and pick a size.")),
        ("checkmark.circle.fill", L("Tap Add Widget. A new artwork appears every day."))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Artwork of the day widget"))
                        .font(.aTitleSmall)
                        .foregroundStyle(Palette.ink)
                    Text(L("One masterpiece on your Home Screen, every morning."))
                        .font(.aBody)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.top, 28)

                HStack(alignment: .top, spacing: 14) {
                    preview(.small, width: 150, height: 150)
                    VStack(spacing: 6) {
                        Mascot(size: 92)
                        Text(L("I'll hang a new painting here every day."))
                            .font(.figtree(14, .semibold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }
                preview(.medium, width: nil, height: 150)
                preview(.large, width: nil, height: 330)

                Text(L("How to add it")).font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(spacing: 12) {
                            Image(systemName: step.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.blue)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Palette.mist))
                            Text(step.text)
                                .font(.aSmall)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        if i < steps.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))

                Button(L("Got it")) { dismiss() }
                    .buttonStyle(.primary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func preview(_ style: DailyWidgetStyle, width: CGFloat?, height: CGFloat) -> some View {
        ZStack {
            DailyWidgetBackground(artwork: artwork, style: style)
            DailyWidgetContent(artwork: artwork, style: style)
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}
