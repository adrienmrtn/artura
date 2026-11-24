import SwiftUI

// MARK: - Buttons

/// Pill button with a bottom lip: it presses down on touch, with haptic feedback.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Palette.blue
    var lip: Color = Palette.blueDark
    var foreground: Color = .white
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyStrong)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Capsule().fill(fill))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(Capsule().fill(lip).offset(y: 3))
            .animation(.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.press() }
            }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var primary: PillButtonStyle { PillButtonStyle() }
    static var secondary: PillButtonStyle {
        PillButtonStyle(fill: Palette.card, lip: Palette.lip, foreground: Palette.ink)
    }
    static var dark: PillButtonStyle {
        // Ink turns light in dark mode: the text follows the background, the lip a mid grey.
        PillButtonStyle(fill: Palette.ink, lip: Color(light: 0x000000, dark: 0xBDB6B0), foreground: Palette.bg)
    }
}

/// Generic style: slight shrink on touch + haptic.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

struct TextLinkButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.figtree(15, .semibold))
                .foregroundStyle(Palette.blueText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Small elements

struct TagPill: View {
    let text: String
    var fill: Color = Palette.yellow
    /// Dark ink in both appearances: the default yellow fill does not change.
    var foreground: Color = Color(hex: 0x2D2C2B)
    var body: some View {
        Text(text)
            .font(.figtree(13, .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }
}

struct ProgressTrack: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule().fill(Palette.blue)
                    .frame(width: max(8, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
        .animation(.gentle, value: value)
    }
}

struct CheckBadge: View {
    var color: Color = Palette.blue
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
    }
}

struct StreakChip: View {
    let days: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").foregroundStyle(Palette.orange)
            Text(days == 1 ? L("1 day") : L("%@ days", "\(days)"))
                .font(.figtree(14, .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Palette.bg))
    }
}

// MARK: - Selectable cards

/// Selectable answer row (onboarding questions).
struct OptionRow: View {
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodyStrong).foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle).font(.aCaption).foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if selected {
                    CheckBadge().transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Palette.mistLight : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.blue : .clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
    }
}

// MARK: - Images

/// Artwork or illustration image, filled and cropped, with optional zoom on a point.
struct ArtImage: View {
    let name: String
    var zoom: CGFloat = 1
    var anchor: UnitPoint = .center

    var body: some View {
        GeometryReader { geo in
            picture(width: geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoom, anchor: anchor)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }

    /// Bundled asset, or picture of the online catalog (a lighter file for small frames).
    @ViewBuilder
    private func picture(width: CGFloat) -> some View {
        if name.hasPrefix("http") {
            if width <= 140, name.hasSuffix("/large.jpg") {
                RemoteImage(url: String(name.dropLast("large.jpg".count)) + "thumb.jpg")
            } else {
                RemoteImage(url: name)
            }
        } else {
            Image(name)
                .resizable()
                .scaledToFill()
        }
    }
}

// MARK: - Sky header (app screens)

struct SkyHeader<Content: View>: View {
    var height: CGFloat = 196
    @ViewBuilder var content: () -> Content
    @State private var drift = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.sky
            Capsule().fill(Palette.skyLight).frame(width: 70, height: 26)
                .offset(x: drift ? 258 : 244, y: 52)
            Circle().fill(Palette.cloud).frame(width: 120, height: 120).offset(x: -30, y: height - 64)
            Circle().fill(Palette.cloud).frame(width: 110, height: 110).offset(x: 290, y: height - 58)
            Circle().fill(Palette.cloud).frame(width: 90, height: 90).offset(x: 350, y: height - 76)
            content()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(ArcHeaderShape())
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Staggered appearance

struct AppearUp: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(delay * 0.5)) { shown = true }
            }
    }
}

extension View {
    /// Fades the view in from below, with a delay (for staggered reveals).
    func appearUp(_ delay: Double = 0) -> some View {
        modifier(AppearUp(delay: delay))
    }
}
