import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    var onExplore: () -> Void = {}
    @State private var showFavorites = false
    @State private var course: Artwork?
    @State private var training = false

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
        f.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return f.string(from: Date())
    }

    private var greeting: String {
        if let name = user.profile.firstName, !name.isEmpty { return L("Hello, %@", name) }
        return L("Hello")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SkyHeader {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(.figtree(28, .semibold))
                        Text(dateLabel).font(.figtree(15))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 24)
                    .padding(.top, 64)
                    StreakChip(days: user.streak)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 24)
                        .padding(.top, 96)
                }

                VStack(alignment: .leading, spacing: 16) {
                    segmented
                    if showFavorites {
                        favorites.transition(.opacity.combined(with: .offset(y: 12)))
                    } else if let art = content.artworkOfTheDay, user.finishedToday(art.id) {
                        doneCard(art).transition(.opacity.combined(with: .offset(y: 12)))
                    } else if let art = content.artworkOfTheDay {
                        dailyCard(art).transition(.opacity.combined(with: .offset(y: 12)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, -34)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(item: $course) { art in
            CourseFlow(artwork: art)
        }
        .fullScreenCover(isPresented: $training) {
            GameHost(kind: .training)
        }
    }

    /// Today's artwork done: congrats, plus ways to keep going.
    private func doneCard(_ art: Artwork) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ArtImage(name: "ill_bravo").frame(height: 230)
                TagPill(text: L("Today's artwork: done"), fill: .white, foreground: Palette.blueText).padding(10)
            }
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text(L("Nice work, you're done for today"))
                        .font(.figtree(24, .semibold)).foregroundStyle(Palette.ink)
                    Text(L("Come back tomorrow for a new artwork. Until then, practice or explore another movement."))
                        .font(.aSmall).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                TrainingButton {
                    Haptics.press()
                    training = true
                }
                Button(L("Explore movements")) {
                    Haptics.tap()
                    onExplore()
                }
                .buttonStyle(.secondary)
                TextLinkButton(title: L("Revisit “%@”", art.title)) { course = art }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .appearUp(0.1)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment(L("For you"), active: !showFavorites) { showFavorites = false }
            segment(L("Favorites"), active: showFavorites) { showFavorites = true }
        }
        .padding(4)
        .background(Capsule().fill(Palette.card))
    }

    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.figtree(15, .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule().fill(active ? Color.white : Color.clear))
        }
        .buttonStyle(.pressable)
    }

    private func dailyCard(_ art: Artwork) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ArtImage(name: art.image).frame(height: 392).zoomable(art)
                TagPill(text: L("Artwork of the day"), fill: .white, foreground: Palette.blueText).padding(10)
                Button {
                    Haptics.press()
                    withAnimation(.bouncy) { user.toggleFavorite(art.id) }
                } label: {
                    Image(systemName: user.isFavorite(art.id) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(user.isFavorite(art.id) ? Palette.orange : Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white))
                        .scaleEffect(user.isFavorite(art.id) ? 1.1 : 1)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(user.isFavorite(art.id) ? L("Remove from favorites") : L("Add to favorites"))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(10)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(art.title).font(.aCardTitle).foregroundStyle(Palette.ink)
                    Text(L("%@ · lesson and quiz", art.meta)).font(.aCaption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Button {
                    course = art
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Palette.blue))
                        .background(Circle().fill(Palette.blueDark).offset(y: 3))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(L("Start the lesson"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            Haptics.tap()
            course = art
        }
        .appearUp(0.1)
    }

    @ViewBuilder
    private var favorites: some View {
        let items = user.profile.favorites.compactMap { content.artwork($0) }
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "heart").font(.system(size: 30)).foregroundStyle(Palette.muted)
                Text(L("No favorites yet")).font(.bodyStrong).foregroundStyle(Palette.ink)
                Text(L("Tap the heart on an artwork to find it here."))
                    .font(.aSmall).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        } else {
            VStack(spacing: 12) {
                ForEach(items) { art in
                    ArtworkRow(artwork: art) { course = art }
                }
            }
        }
    }
}

/// "Thumbnail + title + chevron" row, reused on several screens.
struct ArtworkRow: View {
    let artwork: Artwork
    var done: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ArtImage(name: artwork.image)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(artwork.title).font(.bodyStrong).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(artwork.meta).font(.aCaption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if done {
                    CheckBadge(color: Palette.green, size: 24)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
        }
        .buttonStyle(.pressable)
    }
}
