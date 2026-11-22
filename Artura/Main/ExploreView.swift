import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore

    enum Filter: String, CaseIterable {
        case movements = "Movements"
        case artists = "Artists"
        case periods = "Periods"
        case museums = "Museums"
    }

    @State private var filter: Filter = .movements
    @State private var query = ""
    @State private var course: Artwork?
    @State private var movement: Movement?

    private var searchResults: [Artwork] {
        let q = query.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard !q.isEmpty else { return [] }
        return content.artworks.filter { art in
            let hay = "\(art.title) \(art.artist) \(content.movement(art.movementId)?.name ?? "")"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            return hay.contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SkyHeader {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Explore").font(.figtree(28, .semibold)).foregroundStyle(.white)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Palette.ink)
                            TextField("Artwork, artist, movement…", text: $query)
                                .font(.figtree(15))
                                .foregroundStyle(Palette.ink)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                            if !query.isEmpty {
                                Button {
                                    Haptics.tap()
                                    query = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted)
                                }
                                .accessibilityLabel("Clear search")
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Capsule().fill(.white))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                }

                VStack(alignment: .leading, spacing: 14) {
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        results
                    } else {
                        filters
                        switch filter {
                        case .movements: movementsList
                        case .artists: grouped(by: { $0.artist })
                        case .periods: periodsList
                        case .museums: grouped(by: { $0.museum })
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, -30)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .sheet(item: $movement) { item in
            MovementDetailView(movement: item)
                .presentationDragIndicator(.visible)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases, id: \.rawValue) { item in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) { filter = item }
                    } label: {
                        Text(item.rawValue)
                            .font(.figtree(14, .semibold))
                            .foregroundStyle(filter == item ? .white : Palette.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Capsule().fill(filter == item ? Palette.ink : Palette.card))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var results: some View {
        if searchResults.isEmpty {
            Text("No artwork matches “\(query)”.")
                .font(.aBody).foregroundStyle(Palette.muted).padding(.top, 24)
        } else {
            ForEach(searchResults) { art in
                ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) { course = art }
            }
        }
    }

    @ViewBuilder
    private var movementsList: some View {
        if let current = content.movement(content.artwork(user.profile.firstCourse)?.movementId) ?? content.movements.first,
           let cover = content.artwork(current.cover) {
            let all = content.artworks(in: current.id)
            let done = all.filter { user.profile.completedLessons.contains($0.id) }.count
            Button {
                movement = current
            } label: {
                HStack(spacing: 0) {
                    ArtImage(name: cover.image).frame(width: 112, height: 124)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're here · \(done) of \(all.count)").font(.figtree(12, .semibold))
                        Text(current.name).font(.aCardTitle)
                        Text(current.summary).font(.aCaption).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        ProgressTrack(value: all.isEmpty ? 0 : Double(done) / Double(all.count))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .frame(height: 124)
                .background(Palette.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.pressable)
            .appearUp(0.05)
        }

        Text("The major movements").font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)

        ForEach(Array(content.movements.enumerated()), id: \.element.id) { i, item in
            Button {
                movement = item
            } label: {
                HStack(spacing: 14) {
                    ArtImage(name: content.artwork(item.cover)?.image ?? "art_nuit")
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.bodyStrong).foregroundStyle(Palette.ink)
                        Text("\(item.period) · \(item.summary)").font(.aCaption).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
            .buttonStyle(.pressable)
            .appearUp(0.05 * Double(i + 1))
        }
    }

    private var periodsList: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(content.artworks.sorted { $0.year < $1.year }) { art in
                HStack(spacing: 12) {
                    Text(art.yearLabel)
                        .font(.figtree(15, .semibold))
                        .foregroundStyle(Palette.blueText)
                        .frame(width: 48, alignment: .leading)
                    ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) { course = art }
                }
            }
        }
    }

    private func grouped(by key: @escaping (Artwork) -> String) -> some View {
        let groups = Dictionary(grouping: content.artworks, by: key).sorted { $0.key < $1.key }
        return LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.key) { group in
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text(group.key).font(.aHeading).foregroundStyle(Palette.ink)
                    ForEach(group.value) { art in
                        ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) { course = art }
                    }
                }
            }
        }
    }
}

/// Movement detail: an explanation, then the artworks to study.
struct MovementDetailView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    let movement: Movement
    @State private var course: Artwork?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let cover = content.artwork(movement.cover) {
                    ArtImage(name: cover.image)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                VStack(alignment: .leading, spacing: 6) {
                    TagPill(text: movement.period)
                    Text(movement.name).font(.aTitle).foregroundStyle(Palette.ink)
                    Text(movement.description)
                        .font(.figtree(17)).lineSpacing(5).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("The artworks").font(.aHeading).foregroundStyle(Palette.ink)
                ForEach(content.artworks(in: movement.id)) { art in
                    ArtworkRow(artwork: art, done: user.profile.completedLessons.contains(art.id)) {
                        course = art
                    }
                }
            }
            .padding(24)
        }
        .background(Palette.bg)
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
    }
}
