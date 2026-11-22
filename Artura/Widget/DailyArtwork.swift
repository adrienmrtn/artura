import Foundation

// Shared with the widget extension (target membership: Artura and ArturaWidget).
// Keep this file free of any app-only type.

/// The few fields the widget needs, read from the same `content.json` as the app.
struct DailyArtwork: Decodable, Hashable {
    let id: String
    let title: String
    let artist: String
    let yearLabel: String
    let image: String
    let teaser: String
}

enum DailyCatalog {
    private struct Bundle_: Decodable { let artworks: [DailyArtwork] }

    static let artworks: [DailyArtwork] = {
        guard let url = AppLanguage.resource("content", "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(Bundle_.self, from: data) else { return [] }
        return bundle.artworks
    }()

    /// Same rule as `ContentStore.artworkOfTheDay`, so the widget and the feed always agree.
    static func artwork(on date: Date = Date()) -> DailyArtwork? {
        guard !artworks.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return artworks[day % artworks.count]
    }
}
