import SwiftUI

/// Links used when sharing. The App Store address is unknown until the app is published.
enum AppLinks {
    /// App Store page of the app, added to shared messages once it exists.
    static let appStore: URL? = nil
    /// Address that receives suggestions. Empty: the "Suggest an idea" row is hidden.
    static let supportEmail = "support@vikstudios.com"
}

extension Artwork {
    /// Text that goes with a shared artwork.
    var shareMessage: String {
        var text = "“\(title)” by \(artist), \(yearLabel). I'm learning its story on Artura."
        if let url = AppLinks.appStore { text += " \(url.absoluteString)" }
        return text
    }
}

/// Shares an artwork: its image, with a short message.
struct ArtworkShareLink<Label: View>: View {
    let artwork: Artwork
    @ViewBuilder var label: () -> Label

    var body: some View {
        ShareLink(item: Image(artwork.image),
                  subject: Text(artwork.title),
                  message: Text(artwork.shareMessage),
                  preview: SharePreview(artwork.title, image: Image(artwork.image))) {
            label()
        }
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
        .accessibilityLabel("Share \(artwork.title)")
    }
}

/// Round white button used under a feed card (share, like, save).
struct RoundActionLabel: View {
    let symbol: String
    var tint: Color = Palette.ink
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(.white))
            .background(Circle().fill(Palette.lip).offset(y: 3))
            .overlay(Circle().stroke(Palette.line, lineWidth: 1))
    }
}
