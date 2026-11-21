import SwiftUI

/// Timeline: put four artworks back in order, from oldest to newest.
struct ChronologyGame: View {
    @EnvironmentObject private var content: ContentStore
    let onFinish: (Int, Int) -> Void

    @State private var items: [Artwork] = []
    @State private var checked = false

    private var sortedIDs: [String] { items.sorted { $0.year < $1.year }.map(\.id) }

    private var score: Int {
        zip(items.map(\.id), sortedIDs).filter { $0 == $1 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("From oldest to newest").font(.aTitleSmall).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(checked ? "\(score) artwork\(score == 1 ? "" : "s") in the right spot." : "Drag the artworks by the handle to put them in order.")
                    .font(.aBody).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 24)

            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, art in
                    row(art, position: position)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 24, bottom: 5, trailing: 16))
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(checked ? .inactive : .active))

            Button(checked ? "See my score" : "Check the order") {
                if checked {
                    onFinish(score, items.count)
                } else {
                    withAnimation(.gentle) { checked = true }
                    if score == items.count { Haptics.success() } else { Haptics.warning() }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
        .onAppear {
            if items.isEmpty { items = Array(content.artworks.shuffled().prefix(4)) }
        }
    }

    private func row(_ art: Artwork, position: Int) -> some View {
        let wellPlaced = sortedIDs.indices.contains(position) && sortedIDs[position] == art.id
        return HStack(spacing: 12) {
            ArtImage(name: art.image)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(art.title).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                Text(checked ? "\(art.artist) · \(art.yearLabel)" : art.artist)
                    .font(.aCaption).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            if checked {
                if wellPlaced {
                    CheckBadge(color: Palette.green, size: 24)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Palette.red))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(checked ? (wellPlaced ? Palette.greenSoft : Palette.redSoft) : Palette.card))
    }

    private func move(from source: IndexSet, to destination: Int) {
        Haptics.selection()
        items.move(fromOffsets: source, toOffset: destination)
    }
}
