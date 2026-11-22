import SwiftUI

/// Sheets that can open from the feed's top bar.
enum FeedSheet: Identifiable {
    case filter
    case search
    case library(LibraryTab)

    var id: String {
        switch self {
        case .filter: return "filter"
        case .search: return "search"
        case .library(let tab): return "library-\(tab.rawValue)"
        }
    }

    /// Sheet to open at launch, from the `-feedSheet` debug argument.
    static var debugInitial: FeedSheet? {
        switch AppDebug.string("feedSheet") {
        case "filter": return .filter
        case "search": return .search
        case "history": return .library(.history)
        case "library": return .library(.favorites)
        case "saved": return .library(.saved)
        default: return nil
        }
    }
}

/// Home: a vertical feed, one artwork per screen. Swipe up for the next one,
/// open its lesson, like it, save it or share it.
struct HomeFeedView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var pro: ProStore
    var onExplore: () -> Void = {}
    var onReview: () -> Void = {}

    @State private var filter = FeedFilter()
    /// Order of the feed for this session, so cards don't jump around while reading.
    @State private var order: [String] = []
    /// Drawn once per launch: the feed order changes from one launch to the next.
    private static let sessionSeed = UInt64.random(in: 0...UInt64.max)
    @State private var course: Artwork?
    @State private var sheet: FeedSheet? = FeedSheet.debugInitial
    @State private var showPaywall = false
    /// The artwork the feed is resting on.
    @State private var current: String?

    private var items: [Artwork] {
        order.compactMap { content.artwork($0) }
            .filter { filter.matches($0, read: user.profile.completedLessons.contains($0.id)) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, art in
                            FeedCard(artwork: art,
                                     isDaily: !filter.isActive && art.id == content.artworkOfTheDay?.id,
                                     showHint: index == 0 && items.count > 1,
                                     onOpen: { course = art })
                                .frame(width: geo.size.width, height: geo.size.height)
                                // The next paintings load while this one is on screen: no waiting when scrolling.
                                .onAppear { preload(after: index) }
                        }
                        FeedEndCard(filtered: filter.isActive,
                                    empty: items.isEmpty,
                                    onClearFilter: { withAnimation(.gentle) { filter = FeedFilter() } },
                                    onReview: onReview,
                                    onExplore: onExplore)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $current)
                .onChange(of: current) { old, new in
                    // A tick under the finger each time another artwork comes up.
                    if old != nil, new != nil { Haptics.rigid() }
                }
                .scrollIndicators(.hidden)
                // A new filter starts the feed again from the top.
                .id(filter)
            }

            topBar
        }
        .background(Palette.bg)
        .onAppear(perform: buildOrder)
        .onChange(of: content.artworks.count) { _, _ in
            // The online catalog has replaced the bundled one: rebuild the feed.
            order = []
            buildOrder()
        }
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallScreen(onClose: { showPaywall = false })
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .filter:
                FeedFilterSheet(filter: $filter)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .search:
                FeedSearchSheet(filter: $filter)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .library(let tab):
                LibraryView(tab: tab)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    /// Today's artwork first, then the ones not read yet, then the rest.
    /// Shuffled anew at each launch of the app, then kept for the session so cards don't jump around.
    private func buildOrder() {
        guard order.isEmpty else { return }
        var generator = SeededGenerator(seed: Self.sessionSeed)
        let daily = content.artworkOfTheDay?.id
        let others = content.artworks.filter { $0.id != daily }.shuffled(using: &generator)
        let unread = others.filter { !user.profile.completedLessons.contains($0.id) }
        let read = others.filter { user.profile.completedLessons.contains($0.id) }
        order = ([daily].compactMap { $0 }) + (unread + read).map(\.id)
    }

    /// Downloads the pictures of the three artworks that follow the one at `index`.
    private func preload(after index: Int) {
        let list = items
        guard index + 1 < list.count else { return }
        ImageStore.shared.prefetch(list[(index + 1)...min(index + 3, list.count - 1)].map(\.image))
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            barButton(pro.isPro ? "crown.fill" : "crown", label: pro.isPro ? L("Artura Pro is active") : L("Discover Artura Pro"),
                      tint: pro.isPro ? Palette.yellow : Palette.ink) {
                if !pro.isPro { showPaywall = true }
            }
            barButton("books.vertical", label: L("My library")) { sheet = .library(.favorites) }

            Spacer(minLength: 0)
            StreakChip(days: user.streak)
            Spacer(minLength: 0)

            barButton("clock.arrow.circlepath", label: L("History")) { sheet = .library(.history) }
            barButton("line.3.horizontal.decrease", label: filter.isActive ? L("Filter, %@ active", "\(filter.count)") : L("Filter"),
                      badge: filter.count) { sheet = .filter }
            barButton("magnifyingglass", label: L("Search")) { sheet = .search }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        // Blue header behind the buttons, up to the top of the screen.
        .background(Palette.sky.ignoresSafeArea(edges: .top))
    }

    private func barButton(_ symbol: String, label: String, tint: Color = Palette.ink, badge: Int = 0,
                           action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.figtree(11, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Palette.orange))
                            .offset(x: 3, y: -3)
                    }
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

/// Deterministic random numbers, so the feed keeps the same order for the whole session.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 0xD1B54A32D192ED03
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var value = state
        value ^= value >> 33
        value = value &* 0xFF51AFD7ED558CCD
        value ^= value >> 33
        return value
    }
}

// MARK: - One card of the feed

struct FeedCard: View {
    @EnvironmentObject private var user: UserStore
    let artwork: Artwork
    var isDaily: Bool = false
    /// Shows the "swipe up" hint (first card only).
    var showHint: Bool = false
    let onOpen: () -> Void

    @State private var burst = false
    @State private var zoomed: ZoomTarget?
    @State private var drift = false
    @State private var nudge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liked: Bool { user.isFavorite(artwork.id) }
    private var saved: Bool { user.isSaved(artwork.id) }
    private var read: Bool { user.profile.completedLessons.contains(artwork.id) }

    var body: some View {
        VStack(spacing: 0) {
            // Room for the top bar, which floats above the feed.
            Color.clear.frame(height: 68)

            ArtImage(name: artwork.image, zoom: drift ? 1.06 : 1, anchor: artwork.focusPoint)
                .frame(minHeight: 160, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if isDaily {
                        TagPill(text: L("Artwork of the day"), fill: .white, foreground: Palette.blueText).padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if read {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            Text(L("Read")).font(.figtree(13, .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Palette.green))
                        .padding(12)
                    }
                }
                .overlay {
                    // Heart that pops when the artwork is liked with a double tap.
                    Image(systemName: "heart.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .scaleEffect(burst ? 1 : 0.4)
                        .opacity(burst ? 0.95 : 0)
                        .allowsHitTesting(false)
                }
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture(count: 2) { likeWithBurst() }
                .onTapGesture {
                    // A tap opens the painting full screen, where it can be zoomed.
                    Haptics.tap()
                    zoomed = ZoomTarget(artwork)
                }
                .zoomViewer($zoomed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(artwork.title), \(artwork.artist)")
                .accessibilityHint(L("Opens the painting full screen"))
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 6) {
                Text(artwork.title)
                    .font(.figtree(26, .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(artwork.meta)
                    .font(.figtree(15, .medium))
                    .foregroundStyle(Palette.muted)
                Text(artwork.teaser)
                    .font(.figtree(15))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            .padding(.top, 14)

            Button {
                onOpen()
            } label: {
                HStack(spacing: 8) {
                    Text(read ? L("Read the story again") : L("Discover the story"))
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                }
            }
            .buttonStyle(.primary)
            .padding(.top, 14)

            HStack(spacing: 18) {
                ArtworkShareLink(artwork: artwork) {
                    RoundActionLabel(symbol: "square.and.arrow.up")
                }
                Button {
                    Haptics.press()
                    withAnimation(.bouncy) { user.toggleFavorite(artwork.id) }
                } label: {
                    RoundActionLabel(symbol: liked ? "heart.fill" : "heart", tint: liked ? Palette.orange : Palette.ink)
                        .scaleEffect(liked ? 1.06 : 1)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(liked ? L("Remove from favorites") : L("Add to favorites"))
                Button {
                    Haptics.press()
                    withAnimation(.bouncy) { user.toggleSaved(artwork.id) }
                } label: {
                    RoundActionLabel(symbol: saved ? "bookmark.fill" : "bookmark", tint: saved ? Palette.blue : Palette.ink)
                        .scaleEffect(saved ? 1.06 : 1)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(saved ? L("Remove from saved") : L("Save for later"))
            }
            .padding(.top, 12)

            // Swipe hint under the first card.
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .offset(y: nudge ? -3 : 3)
                .opacity(showHint ? 0.8 : 0)
                .frame(height: 22)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { nudge = true }
        }
    }

    private func likeWithBurst() {
        Haptics.success()
        if !liked { user.toggleFavorite(artwork.id) }
        withAnimation(.easeOut(duration: 0.2)) { burst = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.25)) { burst = false }
        }
    }
}

// MARK: - Last card: nothing left to scroll

struct FeedEndCard: View {
    @EnvironmentObject private var user: UserStore
    let filtered: Bool
    /// True when the filter leaves no artwork at all.
    let empty: Bool
    let onClearFilter: () -> Void
    let onReview: () -> Void
    let onExplore: () -> Void

    private var title: String {
        if empty { return L("Nothing here yet.") }
        return filtered ? L("That's all for this filter.") : L("You're all caught up.")
    }

    private var detail: String {
        if filtered { return L("Clear the filter to see every artwork again.") }
        return L("A new artwork arrives tomorrow. Until then, review what you've learned.")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 70)
            MascotBubble(mascotSize: 150) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.figtree(24, .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.figtree(15))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            VStack(spacing: 10) {
                if filtered {
                    Button(L("Clear the filter")) {
                        Haptics.tap()
                        onClearFilter()
                    }
                    .buttonStyle(.primary)
                } else {
                    Button(L("Review what I've learned")) {
                        Haptics.press()
                        onReview()
                    }
                    .buttonStyle(.primary)
                    Button(L("Explore movements")) {
                        Haptics.tap()
                        onExplore()
                    }
                    .buttonStyle(.secondary)
                }
            }
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }
}
