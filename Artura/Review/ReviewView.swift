import SwiftUI

/// Review tab: a daily set of cards drawn from what the user has read,
/// and free practice on favorites, on everything read, or on every artwork.
struct ReviewView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore

    /// Labels of the two modes, shown by the picker: [Review, Practice].
    private static let modes = [L("Review"), L("Practice")]

    @State private var mode = AppDebug.string("reviewMode") == "practice" ? ReviewView.modes[1] : ReviewView.modes[0]
    @State private var deck: ReviewDeck?
    @State private var course: Artwork?
    @State private var library: LibraryTab?
    @State private var opened = false

    /// Lessons finished, plus artworks opened: what the daily review draws from.
    private var readArtworks: [Artwork] {
        var seen = Set<String>()
        return (user.profile.completedLessons + user.profile.opened)
            .filter { seen.insert($0).inserted }
            .compactMap { content.artwork($0) }
    }

    private var favoriteArtworks: [Artwork] {
        user.profile.favorites.reversed().compactMap { content.artwork($0) }
    }

    private var savedArtworks: [Artwork] {
        (user.profile.saved ?? []).reversed().compactMap { content.artwork($0) }
    }

    private var dailyCount: Int {
        min(ReviewDeck.dailySize, ReviewDeck.available(from: readArtworks, all: content.artworks))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SkyHeader {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Review")).font(.figtree(28, .semibold))
                        Text(L("Remember what you've seen")).font(.figtree(15))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 24)
                    .padding(.top, 64)
                }

                VStack(alignment: .leading, spacing: 16) {
                    SegmentedPicker(options: Self.modes, selection: $mode)
                    if mode == Self.modes[0] {
                        todayCard
                        shelf(title: L("Saved"), icon: "bookmark.fill", tint: Palette.blue,
                              items: savedArtworks, tab: .saved,
                              empty: L("Tap the bookmark on an artwork to read it later."))
                        shelf(title: L("Favorites"), icon: "heart.fill", tint: Palette.orange,
                              items: favoriteArtworks, tab: .favorites,
                              empty: L("Tap the heart on an artwork to find it here."))
                    } else {
                        practiceOptions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, -30)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(item: $deck) { ReviewSessionView(deck: $0) }
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .sheet(item: $library) { tab in
            LibraryView(tab: tab)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Debug: open a session right away, for screenshots.
            guard !opened, AppDebug.flag("reviewSession") else { return }
            opened = true
            deck = ReviewDeck.daily(artworks: readArtworks, all: content.artworks)
        }
    }

    // MARK: Today's review

    private var todayCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("TODAY"))
                        .font(.figtree(12, .bold))
                        .tracking(2.5)
                        .foregroundStyle(Palette.muted)
                    if dailyCount == 0 {
                        Text(L("Nothing to review yet"))
                            .font(.figtree(22, .semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L("Read your first lesson, and its questions will come back here."))
                            .font(.aSmall)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(dailyCount)")
                                .font(.figtree(52, .bold))
                                .foregroundStyle(Palette.ink)
                            // L: shown after the number of review cards, in a larger font ("10 cards").
                            Text(dailyCount == 1 ? L("card") : L("cards"))
                                .font(.figtree(22, .semibold))
                                .foregroundStyle(Palette.ink)
                        }
                        Text(user.reviewDoneToday ? L("Done for today. Come back tomorrow for a new set.")
                                                  : L("drawn from what you've read"))
                            .font(.aSmall)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                ArtImage(name: "ill_regard")
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
            }
            .padding(16)

            Rectangle().fill(Palette.line).frame(height: 1)

            Button {
                Haptics.press()
                if dailyCount == 0 {
                    if let art = content.artworkOfTheDay { course = art }
                } else {
                    deck = ReviewDeck.daily(artworks: readArtworks, all: content.artworks)
                }
            } label: {
                HStack {
                    if user.reviewDoneToday && dailyCount > 0 {
                        CheckBadge(color: Palette.green, size: 22)
                    }
                    Text(dailyCount == 0 ? L("Open today's artwork") : (user.reviewDoneToday ? L("Review again") : L("Review now")))
                        .font(.figtree(17, .semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
            }
            .buttonStyle(.pressable)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
        .appearUp(0.05)
    }

    // MARK: Saved and favorites

    private func shelf(title: String, icon: String, tint: Color, items: [Artwork], tab: LibraryTab, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(.aHeading).foregroundStyle(Palette.ink)
                Spacer()
                if !items.isEmpty {
                    Button(L("See all %@", "\(items.count)")) {
                        Haptics.tap()
                        library = tab
                    }
                    .font(.figtree(14, .semibold))
                    .foregroundStyle(Palette.blueText)
                    .frame(height: 32)
                    .buttonStyle(.pressable)
                }
            }
            if items.isEmpty {
                Text(empty)
                    .font(.aSmall).foregroundStyle(Palette.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(items) { art in
                            LibraryTile(artwork: art, done: user.profile.completedLessons.contains(art.id)) {
                                course = art
                            }
                            .frame(width: 132)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Practice

    @ViewBuilder
    private var practiceOptions: some View {
        Text(L("Choose what to practice")).font(.aHeading).foregroundStyle(Palette.ink)
        practiceRow(title: L("My favorites"), detail: L("The artworks you liked"),
                    image: favoriteArtworks.first?.image ?? "ill_palette",
                    artworks: favoriteArtworks, empty: L("Like an artwork first"))
        practiceRow(title: L("Everything I've read"), detail: L("Every lesson you've opened"),
                    image: readArtworks.first?.image ?? "ill_oeil",
                    artworks: readArtworks, empty: L("Read a lesson first"))
        practiceRow(title: L("All artworks"), detail: L("The whole collection, mixed"),
                    image: "ill_galerie",
                    artworks: content.artworks, empty: L("No artwork available"))
    }

    private func practiceRow(title: String, detail: String, image: String, artworks: [Artwork], empty: String) -> some View {
        let available = ReviewDeck.available(from: artworks, all: content.artworks)
        return Button {
            Haptics.press()
            deck = ReviewDeck.practice(title: title, artworks: artworks, all: content.artworks)
        } label: {
            HStack(spacing: 14) {
                ArtImage(name: image).frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.aCardTitle).foregroundStyle(Palette.ink)
                    Text(available == 0 ? empty : (artworks.count == 1 ? L("%@ · 1 artwork", detail) : L("%@ · %@ artworks", detail, "\(artworks.count)")))
                        .font(.aCaption).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.trailing, 14)
            }
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.pressable)
        .disabled(available == 0)
        .opacity(available == 0 ? 0.5 : 1)
    }
}
