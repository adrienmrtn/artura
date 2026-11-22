import SwiftUI

enum LibraryTab: String, CaseIterable, Identifiable {
    case favorites = "Favorites"
    case saved = "Saved"
    case history = "History"

    var id: String { rawValue }

    var emptyIcon: String {
        switch self {
        case .favorites: return "heart"
        case .saved: return "bookmark"
        case .history: return "clock.arrow.circlepath"
        }
    }

    var emptyTitle: String {
        switch self {
        case .favorites: return "No favorites yet"
        case .saved: return "Nothing saved yet"
        case .history: return "No history yet"
        }
    }

    var emptyDetail: String {
        switch self {
        case .favorites: return "Tap the heart on an artwork to find it here."
        case .saved: return "Tap the bookmark on an artwork to read it later."
        case .history: return "The artworks you open will show up here."
        }
    }
}

/// The user's library: liked artworks, saved artworks and the ones already opened.
struct LibraryView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @Environment(\.dismiss) private var dismiss

    @State var tab: LibraryTab
    @State private var course: Artwork?
    @State private var deck: ReviewDeck?

    private var items: [Artwork] {
        let ids: [String]
        switch tab {
        case .favorites: ids = user.profile.favorites.reversed()
        case .saved: ids = (user.profile.saved ?? []).reversed()
        case .history: ids = user.profile.opened.reversed()
        }
        return ids.compactMap { content.artwork($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My library")
                .font(.aTitle)
                .foregroundStyle(Palette.ink)
                .padding(.top, 24)

            SegmentedPicker(options: LibraryTab.allCases.map(\.rawValue), selection: Binding(
                get: { tab.rawValue },
                set: { tab = LibraryTab(rawValue: $0) ?? .favorites }
            ))

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: tab.emptyIcon).font(.system(size: 30)).foregroundStyle(Palette.muted)
                    Text(tab.emptyTitle).font(.bodyStrong).foregroundStyle(Palette.ink)
                    Text(tab.emptyDetail)
                        .font(.aSmall).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 14) {
                        ForEach(items) { art in
                            LibraryTile(artwork: art, done: user.profile.completedLessons.contains(art.id)) {
                                course = art
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)

                Button("Practice these \(items.count) artwork\(items.count == 1 ? "" : "s")") {
                    Haptics.press()
                    deck = ReviewDeck.practice(title: tab.rawValue, artworks: items, all: content.artworks)
                }
                .buttonStyle(.primary)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg.ignoresSafeArea())
        .animation(.snappy, value: tab)
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .fullScreenCover(item: $deck) { ReviewSessionView(deck: $0) }
    }
}

/// Square thumbnail with the title underneath.
struct LibraryTile: View {
    let artwork: Artwork
    var done: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ArtImage(name: artwork.image)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .topTrailing) {
                        if done { CheckBadge(color: Palette.green, size: 24).padding(8) }
                    }
                Text(artwork.title)
                    .font(.figtree(15, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(artwork.artist)
                    .font(.aCaption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(artwork.title), \(artwork.artist)\(done ? ", read" : "")")
    }
}

/// Capsule selector with a white pill under the active option (same look as the app's other selectors).
struct SegmentedPicker: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    guard selection != option else { return }
                    Haptics.selection()
                    withAnimation(.snappy) { selection = option }
                } label: {
                    Text(option)
                        .font(.figtree(15, .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Capsule().fill(selection == option ? Color.white : Color.clear))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Palette.card))
    }
}
