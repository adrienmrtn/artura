import SwiftUI
import CoreText
import UIKit

// Shared with the widget extension (target membership: Artura and ArturaWidget).
// The app uses these views to preview the widget; the extension draws the real one.

enum DailyWidgetStyle {
    case small, medium, large, lockScreen
}

/// Colors and fonts of the app, repeated here because the extension does not see `Palette`.
private enum WidgetLook {
    static let bg = Color.white
    static let ink = Color(red: 0x2D / 255, green: 0x2C / 255, blue: 0x2B / 255)
    static let muted = Color(red: 0x5C / 255, green: 0x57 / 255, blue: 0x53 / 255)
    static let blue = Color(red: 0x1C / 255, green: 0x36 / 255, blue: 0x5A / 255)
    static let mist = Color(red: 0xE3 / 255, green: 0xEA / 255, blue: 0xF4 / 255)

    private static let registered: Bool = {
        for name in ["Figtree_400Regular", "Figtree_600SemiBold", "Figtree_700Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        _ = registered
        switch weight {
        case .bold: return .custom("Figtree-Bold", size: size)
        case .semibold: return .custom("Figtree-SemiBold", size: size)
        default: return .custom("Figtree-Regular", size: size)
        }
    }
}

/// The painting, filling its frame. Falls back to a plain tint if the image is not in the bundle.
private struct WidgetPainting: View {
    let name: String

    var body: some View {
        if let image = UIImage(named: name) {
            Color.clear.overlay(
                Image(uiImage: image).resizable().scaledToFill()
            )
            .clipped()
        } else {
            WidgetLook.mist
        }
    }
}

/// What sits behind the widget content (edge to edge).
struct DailyWidgetBackground: View {
    let artwork: DailyArtwork?
    let style: DailyWidgetStyle

    var body: some View {
        switch style {
        case .small:
            if let artwork {
                WidgetPainting(name: artwork.image)
                    .overlay(
                        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.72)],
                                       startPoint: .center, endPoint: .bottom)
                    )
            } else {
                WidgetLook.bg
            }
        case .medium, .large:
            WidgetLook.bg
        case .lockScreen:
            Color.clear
        }
    }
}

/// The widget content, for each size.
struct DailyWidgetContent: View {
    let artwork: DailyArtwork?
    let style: DailyWidgetStyle

    var body: some View {
        if let artwork {
            switch style {
            case .small: small(artwork)
            case .medium: medium(artwork)
            case .large: large(artwork)
            case .lockScreen: lockScreen(artwork)
            }
        } else {
            Text("Open Artura to see today's artwork")
                .font(WidgetLook.font(13, .semibold))
                .foregroundStyle(WidgetLook.ink)
                .multilineTextAlignment(.center)
                .padding(14)
        }
    }

    private var label: some View {
        Text("ARTWORK OF THE DAY")
            .font(WidgetLook.font(10, .bold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func small(_ artwork: DailyArtwork) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            Text(artwork.title)
                .font(WidgetLook.font(16, .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(artwork.artist)
                .font(WidgetLook.font(12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(14)
    }

    private func medium(_ artwork: DailyArtwork) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                WidgetPainting(name: artwork.image)
                    .frame(width: geo.size.height)
                VStack(alignment: .leading, spacing: 4) {
                    label.foregroundStyle(WidgetLook.blue)
                    Text(artwork.title)
                        .font(WidgetLook.font(18, .bold))
                        .foregroundStyle(WidgetLook.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text("\(artwork.artist) · \(artwork.yearLabel)")
                        .font(WidgetLook.font(12))
                        .foregroundStyle(WidgetLook.muted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(artwork.teaser)
                        .font(WidgetLook.font(12))
                        .foregroundStyle(WidgetLook.muted)
                        .lineLimit(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func large(_ artwork: DailyArtwork) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetPainting(name: artwork.image)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                label.foregroundStyle(WidgetLook.blue)
                Text(artwork.title)
                    .font(WidgetLook.font(21, .bold))
                    .foregroundStyle(WidgetLook.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(artwork.artist) · \(artwork.yearLabel)")
                    .font(WidgetLook.font(13))
                    .foregroundStyle(WidgetLook.muted)
                    .lineLimit(1)
                Text(artwork.teaser)
                    .font(WidgetLook.font(13))
                    .foregroundStyle(WidgetLook.muted)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lockScreen(_ artwork: DailyArtwork) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Artwork of the day")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.7)
            Text(artwork.title)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
            Text(artwork.artist)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
