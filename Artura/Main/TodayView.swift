import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @State private var showFavorites = false
    @State private var course: Artwork?

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        let text = f.string(from: Date())
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private var greeting: String {
        if let name = user.profile.firstName, !name.isEmpty { return "Bonjour \(name)" }
        return "Bonjour"
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
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment("Pour toi", active: !showFavorites) { showFavorites = false }
            segment("Favoris", active: showFavorites) { showFavorites = true }
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
                ArtImage(name: art.image).frame(height: 392)
                TagPill(text: "Œuvre du jour", fill: .white, foreground: Palette.blueText).padding(10)
                Button {
                    Haptics.tap()
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
                .accessibilityLabel(user.isFavorite(art.id) ? "Retirer des favoris" : "Ajouter aux favoris")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(10)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(art.title).font(.aCardTitle).foregroundStyle(Palette.ink)
                    Text("\(art.meta) · cours et quiz").font(.aCaption).foregroundStyle(Palette.muted)
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
                .accessibilityLabel("Commencer le cours")
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
                Text("Pas encore de favoris").font(.bodyStrong).foregroundStyle(Palette.ink)
                Text("Touche le cœur sur une œuvre pour la retrouver ici.")
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

/// Ligne « vignette + titre + chevron » réutilisée dans plusieurs écrans.
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
