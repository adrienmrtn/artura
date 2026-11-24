import SwiftUI

// MARK: - Filter model

/// What the home feed is narrowed to. Everything is optional: an empty filter shows all artworks.
struct FeedFilter: Hashable {
    enum Status: String, CaseIterable {
        case all = "Everything"
        case unread = "Not read yet"
        case read = "Already read"

        /// Label shown on screen (the raw value is an identifier).
        var label: String {
            switch self {
            case .all: return L("Everything")
            case .unread: return L("Not read yet")
            case .read: return L("Already read")
            }
        }
    }

    var movementId: String?
    var artist: String?
    /// Century of the artwork (15 = 15th century).
    var century: Int?
    var status: Status = .all

    var isActive: Bool {
        movementId != nil || artist != nil || century != nil || status != .all
    }

    /// Number of criteria currently set, shown on the filter button.
    var count: Int {
        [movementId != nil, artist != nil, century != nil, status != .all].filter { $0 }.count
    }

    func matches(_ artwork: Artwork, read: Bool) -> Bool {
        if let movementId, artwork.movementId != movementId { return false }
        if let artist, artwork.artist != artist { return false }
        if let century, Self.century(of: artwork.year) != century { return false }
        switch status {
        case .all: return true
        case .unread: return !read
        case .read: return read
        }
    }

    static func century(of year: Int) -> Int {
        year > 0 ? (year - 1) / 100 + 1 : 0
    }

    /// "19th century".
    static func label(forCentury century: Int) -> String {
        // L: "%@" is the century number (Roman numerals in the languages of `romanCenturies`);
        // the English ordinal suffix (st, nd, rd, th) depends on it.
        let number = romanCenturies.contains(AppLanguage.code) ? roman(century) : "\(century)"
        switch (century % 10, century % 100) {
        case (_, 11), (_, 12), (_, 13): return L("%@th century", number)
        case (1, _): return L("%@st century", number)
        case (2, _): return L("%@nd century", number)
        case (3, _): return L("%@rd century", number)
        default: return L("%@th century", number)
        }
    }

    /// Languages that write centuries in Roman numerals ("XIXe siècle", "siglo XIX", "XIX век").
    private static let romanCenturies: Set<String> = ["fr", "es", "it", "pt-BR", "pt-PT", "ro", "pl", "ru", "bg", "sr-Latn", "lt"]

    private static func roman(_ n: Int) -> String {
        guard n > 0 else { return "\(n)" }
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var rest = n
        var out = ""
        for (value, letters) in table {
            while rest >= value {
                out += letters
                rest -= value
            }
        }
        return out
    }
}

// MARK: - Chips that wrap onto several lines

struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Selectable chip used in the filter sheet and the search suggestions.
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.figtree(14, .semibold))
                .foregroundStyle(selected ? .white : Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Capsule().fill(selected ? Palette.blue : Palette.bg))
                .overlay(Capsule().stroke(selected ? Palette.blue : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Filter sheet

struct FeedFilterSheet: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: FeedFilter

    /// Edited copy: the feed only changes when the user confirms.
    @State private var draft = FeedFilter()

    private var artists: [String] {
        Array(Set(content.artworks.map(\.artist))).sorted()
    }

    private var centuries: [Int] {
        Array(Set(content.artworks.map { FeedFilter.century(of: $0.year) })).sorted()
    }

    private var matchCount: Int {
        content.artworks.filter { draft.matches($0, read: user.profile.completedLessons.contains($0.id)) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Filter your feed")).font(.aTitleSmall).foregroundStyle(Palette.ink)
                Spacer()
                if draft.isActive {
                    Button(L("Reset")) {
                        Haptics.tap()
                        withAnimation(.snappy) { draft = FeedFilter() }
                    }
                    .font(.figtree(15, .semibold))
                    .foregroundStyle(Palette.blueText)
                    .frame(height: 44)
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(L("Movement")) {
                        ForEach(content.movements) { movement in
                            FilterChip(title: movement.name, selected: draft.movementId == movement.id) {
                                draft.movementId = draft.movementId == movement.id ? nil : movement.id
                            }
                        }
                    }
                    section(L("Period")) {
                        ForEach(centuries, id: \.self) { century in
                            FilterChip(title: FeedFilter.label(forCentury: century), selected: draft.century == century) {
                                draft.century = draft.century == century ? nil : century
                            }
                        }
                    }
                    section(L("Artist")) {
                        ForEach(artists, id: \.self) { artist in
                            FilterChip(title: artist, selected: draft.artist == artist) {
                                draft.artist = draft.artist == artist ? nil : artist
                            }
                        }
                    }
                    section(L("Show")) {
                        ForEach(FeedFilter.Status.allCases, id: \.rawValue) { status in
                            FilterChip(title: status.label, selected: draft.status == status) {
                                draft.status = status
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            Button(matchCount == 0 ? L("No artwork matches") : (matchCount == 1 ? L("Show 1 artwork") : L("Show %@ artworks", "\(matchCount)"))) {
                Haptics.press()
                filter = draft
                dismiss()
            }
            .buttonStyle(.primary)
            .disabled(matchCount == 0)
            .opacity(matchCount == 0 ? 0.4 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.bg.ignoresSafeArea())
        .onAppear { draft = filter }
    }

    private func section<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.aHeading).foregroundStyle(Palette.ink)
            ChipFlow(spacing: 8) { chips() }
        }
    }
}

// MARK: - Search sheet

struct FeedSearchSheet: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @Environment(\.dismiss) private var dismiss
    /// Lets a suggestion narrow the feed (for example, to one movement).
    @Binding var filter: FeedFilter

    @State private var query = ""
    @State private var course: Artwork?
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var results: [Artwork] {
        let needle = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard !needle.isEmpty else { return [] }
        return content.artworks.filter { art in
            let haystack = "\(art.title) \(art.artist) \(art.museum) \(content.movement(art.movementId)?.name ?? "")"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            return haystack.contains(needle)
        }
    }

    private var recent: [Artwork] {
        user.profile.opened.reversed().prefix(4).compactMap { content.artwork($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.ink)
                TextField(L("Artwork, artist, movement…"), text: $query)
                    .font(.figtree(16))
                    .foregroundStyle(Palette.ink)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                if !query.isEmpty {
                    Button {
                        Haptics.tap()
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted)
                    }
                    .accessibilityLabel(L("Clear search"))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Capsule().fill(Palette.bg))
            .overlay(Capsule().stroke(focused ? Palette.blue : Palette.line, lineWidth: focused ? 2 : 1))
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if trimmed.isEmpty {
                        suggestions
                    } else if results.isEmpty {
                        Text(L("No artwork matches “%@”.", trimmed))
                            .font(.aBody).foregroundStyle(Palette.muted)
                            .padding(.top, 12)
                    } else {
                        ForEach(results) { art in
                            ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) {
                                course = art
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg.ignoresSafeArea())
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        Text(L("Browse by movement")).font(.aHeading).foregroundStyle(Palette.ink)
        ChipFlow(spacing: 8) {
            ForEach(content.movements) { movement in
                FilterChip(title: movement.name, selected: false) {
                    var next = FeedFilter()
                    next.movementId = movement.id
                    filter = next
                    dismiss()
                }
            }
        }
        if !recent.isEmpty {
            Text(L("Recently opened")).font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 8)
            ForEach(recent) { art in
                ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) {
                    course = art
                }
            }
        }
    }
}
