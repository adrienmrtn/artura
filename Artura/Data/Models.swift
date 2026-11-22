import SwiftUI

/// A point of interest on the painting, in 0…1 coordinates from the top-left corner.
struct Spot: Codable, Hashable {
    var x: Double
    var y: Double
    var zoom: Double?
    /// Marker radius, as a fraction of the painting's width.
    var r: Double?
    /// "circle" (default), "rect" or "arrow"
    var shape: String?
    var title: String?
    var text: String?
}

/// A line drawn over the painting (composition, gaze, light).
struct GuideLine: Codable, Hashable {
    var points: [[Double]]
    var closed: Bool?
    var label: String
    var text: String
}

/// A palette color, with the image that highlights the areas where it appears.
struct Swatch: Codable, Hashable {
    var hex: String
    var name: String
    var text: String
    var image: String
}

struct LessonBlock: Codable, Hashable {
    /// Reading blocks: "text", "image", "key", "fact".
    /// Interactive blocks, full screen on the painting: "tour", "find", "lines", "palette", "explore".
    let type: String
    var title: String?
    var text: String?
    var caption: String?
    var zoom: Double?
    var anchor: [Double]?
    var spots: [Spot]?
    var lines: [GuideLine]?
    var swatches: [Swatch]?

    var isInteractive: Bool {
        ["tour", "find", "lines", "palette", "explore"].contains(type)
    }

    var interactiveTitle: String {
        if let title { return title }
        switch type {
        case "tour": return L("Guided tour")
        case "find": return L("Find it")
        case "lines": return L("Composition lines")
        case "palette": return L("The palette")
        default: return L("Free zoom")
        }
    }

    var interactiveIcon: String {
        switch type {
        case "tour": return "scope"
        case "find": return "hand.tap.fill"
        case "lines": return "triangle"
        case "palette": return "paintpalette.fill"
        default: return "magnifyingglass"
        }
    }

    var unitAnchor: UnitPoint {
        guard let anchor, anchor.count == 2 else { return .center }
        return UnitPoint(x: anchor[0], y: anchor[1])
    }
}

struct QuizQuestion: Codable, Hashable {
    let question: String
    let options: [String]
    let answer: Int
    let explanation: String
}

struct Fact: Codable, Hashable {
    let text: String
    let isTrue: Bool
    let explanation: String
}

struct Artwork: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let year: Int
    let yearLabel: String
    let museum: String
    let movementId: String
    let image: String
    /// High-definition version, for zooming in the lesson (falls back to `image`).
    var hd: String?
    let palette: [String]
    let focus: [Double]
    let teaser: String
    var lesson: [LessonBlock]
    var quiz: [QuizQuestion]
    var facts: [Fact]
    /// Width / height of the picture. Known for the online catalog, where the image is not in the app.
    var aspect: Double?
    /// Credit line to show with the image, when its license asks for one.
    var credit: String?

    var focusPoint: UnitPoint {
        guard focus.count == 2 else { return .center }
        return UnitPoint(x: focus[0], y: focus[1])
    }

    var paletteColors: [Color] { palette.map { Color(hexString: $0) } }
    var meta: String { "\(artist) · \(yearLabel)" }
    var canvasImage: String { hd ?? image }
    /// True when the images are downloaded (online catalog) instead of bundled with the app.
    var isRemote: Bool { image.hasPrefix("http") }
}

extension Artwork {
    /// Extrait du cours pour l'onboarding : le début, jusqu'à la première interaction,
    /// puis la lecture qui suit jusqu'au premier « À retenir ».
    var previewLesson: [LessonBlock] {
        guard let first = lesson.firstIndex(where: { $0.isInteractive }) else {
            return Array(lesson.prefix(4))
        }
        var end = first
        for i in lesson.indices where i > first {
            if lesson[i].isInteractive { break }
            end = i
            if lesson[i].type == "key" { break }
        }
        return Array(lesson[...end])
    }
}

struct Movement: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let period: String
    let summary: String
    let cover: String
    let description: String
}

struct ContentBundle: Codable {
    let movements: [Movement]
    let artworks: [Artwork]
}

/// The artworks and movements shown in the app.
/// Starts with the content bundled with the app (Resources/content.json), then, once the main
/// app is on screen, switches to the online catalog (saved on the device after the first download).
final class ContentStore: ObservableObject {
    @Published private(set) var movements: [Movement]
    @Published private(set) var artworks: [Artwork] { didSet { reindex() } }

    private let bundled: ContentBundle
    private var byId: [String: Artwork] = [:]
    private var dailyOrder: [Artwork] = []
    private var usesCatalog = false
    private var refreshing = false

    init() {
        if let url = AppLanguage.resource("content", "json"),
           let data = try? Data(contentsOf: url),
           let bundle = try? JSONDecoder().decode(ContentBundle.self, from: data) {
            bundled = bundle
        } else {
            assertionFailure("content.json missing or invalid")
            bundled = ContentBundle(movements: [], artworks: [])
        }
        movements = bundled.movements
        artworks = bundled.artworks
        reindex()
    }

    private func reindex() {
        byId = Dictionary(artworks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Stable shuffle, so the artwork of the day does not walk through the catalog alphabetically.
        dailyOrder = usesCatalog ? artworks.sorted { Self.stableHash($0.id) < Self.stableHash($1.id) } : artworks
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    /// Looks in the current catalog, then in the bundled artworks (onboarding, lessons read before the catalog).
    func artwork(_ id: String?) -> Artwork? {
        guard let id else { return nil }
        return byId[id] ?? bundled.artworks.first { $0.id == id }
    }

    func movement(_ id: String?) -> Movement? {
        guard let id else { return nil }
        return movements.first { $0.id == id } ?? bundled.movements.first { $0.id == id }
    }

    func artworks(in movementId: String) -> [Artwork] {
        artworks.filter { $0.movementId == movementId }
    }

    /// Artwork of the day: changes daily, in a stable way.
    var artworkOfTheDay: Artwork? {
        guard !dailyOrder.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return dailyOrder[day % dailyOrder.count]
    }

    var allFacts: [(fact: Fact, artwork: Artwork)] {
        artworks.flatMap { art in art.facts.map { (fact: $0, artwork: art) } }
    }

    // MARK: Online catalog

    private static let palettes: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let palettes = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return palettes
    }()

    /// Called when the main app appears: shows the saved catalog at once, and updates it when it is old.
    @MainActor
    func activateCatalog() {
        if !usesCatalog, let saved = CatalogCache.loadIndex(), !saved.artworks.isEmpty {
            apply(saved)
        }
        let age = CatalogCache.indexAge
        guard !refreshing, !usesCatalog || age == nil || (age ?? 0) > 6 * 3600 else { return }
        refreshing = true
        Task { @MainActor in
            defer { refreshing = false }
            guard let fresh = try? await RemoteCatalog.index(palettes: Self.palettes), !fresh.artworks.isEmpty else {
                return
            }
            CatalogCache.saveIndex(fresh)
            apply(fresh)
        }
    }

    /// Replaces the catalog, keeping the lessons already on the device.
    @MainActor
    private func apply(_ english: ContentBundle) {
        let bundle = TranslatedCatalog.current?.applied(to: english) ?? english
        let saved = Set(CatalogCache.savedLessons)
        var list = bundle.artworks
        for i in list.indices where list[i].lesson.isEmpty {
            if let known = byId[list[i].id], !known.lesson.isEmpty {
                list[i].lesson = known.lesson
                list[i].quiz = known.quiz
            } else if saved.contains(list[i].id), let content = CatalogCache.loadLesson(list[i].id) {
                list[i].lesson = content.lesson
                list[i].quiz = content.quiz
            }
        }
        usesCatalog = true
        movements = bundle.movements
        artworks = list
    }

    /// The artwork with its lesson and quiz, downloaded if needed. Nil when it cannot be loaded.
    @MainActor
    func withLesson(_ artwork: Artwork) async -> Artwork? {
        if !artwork.lesson.isEmpty { return artwork }
        if let known = byId[artwork.id], !known.lesson.isEmpty { return known }
        guard let content = try? await RemoteCatalog.lesson(artwork.id) else { return nil }
        CatalogCache.saveLesson(content, slug: artwork.id)
        var full = byId[artwork.id] ?? artwork
        full.lesson = content.lesson
        full.quiz = content.quiz
        if let i = artworks.firstIndex(where: { $0.id == full.id }) { artworks[i] = full }
        return full
    }
}

let avatarImages = ["ill_av1", "ill_av2", "ill_av3", "ill_av4", "ill_av5"]
let avatarLabels = [L("Girl with the turban"), L("Man in the straw hat"), L("Cat in a beret"), L("The sun"), L("The moon")]

/// The catalog in the app's language, when it is not English: the translated lessons bundled with the
/// app (Resources/lessons.<code>.json, built by catalog/translations/app/app.py). Only the translated
/// artworks are shown in that language, with their titles, movements, lessons, quizzes and facts.
struct TranslatedCatalog: Decodable {
    struct Meta: Decodable {
        let title: String
        let artist: String
        let year_label: String?
        let museum: String?
    }

    struct Lesson: Decodable {
        let teaser: String
        let lesson: [LessonBlock]
        let quiz: [QuizQuestion]
        let facts: [Fact]
        let meta: Meta
    }

    struct MovementText: Decodable {
        let name: String
        let period: String?
        let summary: String?
        let description: String?
    }

    let movements: [String: MovementText]
    let lessons: [String: Lesson]

    static let current: TranslatedCatalog? = {
        guard !AppLanguage.isEnglish,
              let url = Bundle.main.url(forResource: "lessons.\(AppLanguage.code)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranslatedCatalog.self, from: data)
    }()

    /// The online catalog restricted to the translated artworks, with their text in the app's language.
    func applied(to bundle: ContentBundle) -> ContentBundle {
        let artworks = bundle.artworks.compactMap { a -> Artwork? in
            guard let t = lessons[a.id] else { return nil }
            return Artwork(
                id: a.id, title: t.meta.title, artist: t.meta.artist, year: a.year,
                yearLabel: t.meta.year_label ?? a.yearLabel, museum: t.meta.museum ?? a.museum,
                movementId: a.movementId, image: a.image, hd: a.hd, palette: a.palette, focus: a.focus,
                teaser: t.teaser, lesson: t.lesson, quiz: t.quiz, facts: t.facts,
                aspect: a.aspect, credit: a.credit
            )
        }
        guard !artworks.isEmpty else { return bundle }
        let covers = Dictionary(artworks.map { ($0.movementId, $0.id) }, uniquingKeysWith: { first, _ in first })
        let movementTexts = movements
        let shown = bundle.movements.compactMap { m -> Movement? in
            guard let cover = covers[m.id] else { return nil }
            let t = movementTexts[m.id]
            return Movement(id: m.id, name: t?.name ?? m.name, period: t?.period ?? m.period,
                            summary: t?.summary ?? m.summary, cover: cover, description: t?.description ?? m.description)
        }
        return ContentBundle(movements: shown, artworks: artworks)
    }
}
