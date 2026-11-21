import StoreKit
import SwiftUI

/// Profile rows added under the settings: the library, and ways to support the app.
struct SupportSection: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var showLibrary = false

    private var shareText: String {
        var text = "I'm learning art with Artura: one masterpiece a day, and the story behind it."
        if let url = AppLinks.appStore { text += " \(url.absoluteString)" }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                Button {
                    Haptics.tap()
                    showLibrary = true
                } label: {
                    row("books.vertical.fill", "My library", detail: "Favorites, saved and history")
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))

            Text("Support Artura").font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)

            VStack(spacing: 0) {
                ShareLink(item: shareText) {
                    row("person.2.fill", "Invite a friend", detail: "Learn art together")
                }
                .buttonStyle(.pressable)
                Divider()
                Button {
                    Haptics.tap()
                    requestReview()
                } label: {
                    row("star.fill", "Rate Artura", detail: "It really helps")
                }
                .buttonStyle(.pressable)
                if !AppLinks.supportEmail.isEmpty,
                   let url = URL(string: "mailto:\(AppLinks.supportEmail)?subject=An%20idea%20for%20Artura") {
                    Divider()
                    Button {
                        Haptics.tap()
                        openURL(url)
                    } label: {
                        row("lightbulb.fill", "Suggest an idea", detail: "Tell us what you'd like to see")
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(tab: .favorites)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func row(_ symbol: String, _ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.sand))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.aCaption).foregroundStyle(Palette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.muted)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
