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

    private var bundled: ContentBundle
    private var byId: [String: Artwork] = [:]
    private var dailyOrder: [Artwork] = []
    private var usesCatalog = false
    /// Catalog text in the app's language, downloaded (nil in English or before the first download).
    private var translation: RemoteTranslation?
    private var refreshing = false

    init() {
        bundled = Self.loadBundled()
        movements = bundled.movements
        artworks = bundled.artworks
        reindex()
    }

    private static func loadBundled() -> ContentBundle {
        guard let url = AppLanguage.resource("content", "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(ContentBundle.self, from: data) else {
            assertionFailure("content.json missing or invalid")
            return ContentBundle(movements: [], artworks: [])
        }
        return bundle
    }

    /// The language was changed in the app: everything is shown again in the new language at once
    /// (bundled content, saved catalog), then the online translations are downloaded.
    @MainActor
    func languageChanged() {
        bundled = Self.loadBundled()
        translation = CatalogCache.loadTranslation()
        byId = [:]
        if usesCatalog, let saved = CatalogCache.loadIndex(), !saved.artworks.isEmpty {
            apply(saved)
        } else {
            movements = bundled.movements
            artworks = bundled.artworks
        }
        guard !AppLanguage.isEnglish else { return }
        let language = AppLanguage.code
        Task { @MainActor in
            guard let online = await Self.downloadTranslation(), !online.artworks.isEmpty,
                  language == AppLanguage.code else { return }
            CatalogCache.saveTranslation(online)
            translation = online
            if usesCatalog, let saved = CatalogCache.loadIndex(), !saved.artworks.isEmpty { apply(saved) }
        }
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
            translation = CatalogCache.loadTranslation()
            apply(saved)
        }
        let age = CatalogCache.indexAge
        guard !refreshing, !usesCatalog || age == nil || (age ?? 0) > 6 * 3600 else { return }
        refreshing = true
        Task { @MainActor in
            defer { refreshing = false }
            async let index: ContentBundle? = try? await RemoteCatalog.index(palettes: Self.palettes)
            async let texts: RemoteTranslation? = Self.downloadTranslation()
            let fresh = await index
            let online = await texts
            if let online, !online.artworks.isEmpty {
                CatalogCache.saveTranslation(online)
                translation = online
            }
            guard let fresh, !fresh.artworks.isEmpty else { return }
            CatalogCache.saveIndex(fresh)
            apply(fresh)
        }
    }

    /// Replaces the catalog, keeping the lessons already on the device.
    @MainActor
    private func apply(_ english: ContentBundle) {
        let bundle = TranslatedCatalog.current?.applied(to: english, online: translation) ?? english
        let saved = Set(CatalogCache.savedLessons)
        var list = bundle.artworks
        for i in list.indices where list[i].lesson.isEmpty {
            if let known = byId[list[i].id], !known.lesson.isEmpty {
                list[i].lesson = known.lesson
                list[i].quiz = known.quiz
            } else if saved.contains(Self.lessonKey(list[i].id)), let content = CatalogCache.loadLesson(Self.lessonKey(list[i].id)) {
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
        let downloaded: LessonContent?
        if AppLanguage.isEnglish {
            downloaded = try? await RemoteCatalog.lesson(artwork.id)
        } else {
            downloaded = try? await RemoteCatalog.translatedLesson(artwork.id, language: AppLanguage.code)
        }
        guard let content = downloaded else { return nil }
        CatalogCache.saveLesson(content, slug: Self.lessonKey(artwork.id))
        var full = byId[artwork.id] ?? artwork
        full.lesson = content.lesson
        full.quiz = content.quiz
        if let i = artworks.firstIndex(where: { $0.id == full.id }) { artworks[i] = full }
        return full
    }

    /// Catalog text in the app's language (nil in English, or when it cannot be downloaded).
    private static func downloadTranslation() async -> RemoteTranslation? {
        guard !AppLanguage.isEnglish else { return nil }
        return try? await RemoteCatalog.translations(AppLanguage.code)
    }

    /// Name of a lesson saved on the device: the slug in English, "slug.fr" in French, etc.
    private static func lessonKey(_ id: String) -> String {
        AppLanguage.isEnglish ? id : "\(id).\(AppLanguage.code)"
    }
}

let avatarImages = ["ill_av1", "ill_av2", "ill_av3", "ill_av4", "ill_av5"]
var avatarLabels: [String] { [L("Girl with the turban"), L("Man in the straw hat"), L("Cat in a beret"), L("The sun"), L("The moon")] }

/// The catalog in the app's language, when it is not English: the translated lessons bundled with the
/// app (Resources/lessons.<code>.json, built by catalog/translations/app/app.py). Only the translated
/// artworks are shown in that language, with their titles, movements, lessons, quizzes and facts.
struct TranslatedCatalog: Decodable {
    // Bundled with the app: the 100 translated lessons, used offline and before the first download.
    // Online (`RemoteTranslation`, Supabase *_translations tables): titles, movements and facts, which win
    // over the bundled ones, plus any lesson translated after this version of the app (downloaded on open).
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

    struct MovementText: Codable {
        let name: String
        let period: String?
        let summary: String?
        let description: String?
    }

    let movements: [String: MovementText]
    let lessons: [String: Lesson]

    /// The bundled translations of the current language (nil in English). Reloaded when the language changes.
    static var current: TranslatedCatalog? {
        if let cached, cached.code == AppLanguage.code { return cached.catalog }
        let catalog = load()
        cached = (AppLanguage.code, catalog)
        return catalog
    }

    private static var cached: (code: String, catalog: TranslatedCatalog?)?

    private static func load() -> TranslatedCatalog? {
        guard !AppLanguage.isEnglish else { return nil }
        guard let url = Bundle.main.url(forResource: "lessons.\(AppLanguage.code)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(TranslatedCatalog.self, from: data) else {
            return TranslatedCatalog(movements: [:], lessons: [:])
        }
        return catalog
    }

    /// The online catalog restricted to the translated artworks, with their text in the app's language.
    func applied(to bundle: ContentBundle, online: RemoteTranslation?) -> ContentBundle {
        let artworks = bundle.artworks.compactMap { a -> Artwork? in
            let local = lessons[a.id]
            let remote = online?.artworks[a.id]
            guard let title = remote?.title ?? local?.meta.title,
                  let artist = remote?.artist ?? local?.meta.artist else { return nil }
            let facts = remote.map { $0.facts.isEmpty ? (local?.facts ?? []) : $0.facts } ?? (local?.facts ?? [])
            return Artwork(
                id: a.id, title: title, artist: artist, year: a.year,
                yearLabel: remote?.yearLabel ?? local?.meta.year_label ?? a.yearLabel,
                museum: remote?.museum ?? local?.meta.museum ?? a.museum,
                movementId: a.movementId, image: a.image, hd: a.hd, palette: a.palette, focus: a.focus,
                teaser: remote?.teaser ?? local?.teaser ?? a.teaser,
                lesson: local?.lesson ?? [], quiz: local?.quiz ?? [], facts: facts,
                aspect: a.aspect, credit: a.credit
            )
        }
        guard !artworks.isEmpty else { return bundle }
        let covers = Dictionary(artworks.map { ($0.movementId, $0.id) }, uniquingKeysWith: { first, _ in first })
        var movementTexts = movements
        for (id, text) in online?.movements ?? [:] { movementTexts[id] = text }
        let shown = bundle.movements.compactMap { m -> Movement? in
            guard let cover = covers[m.id] else { return nil }
            let t = movementTexts[m.id]
            return Movement(id: m.id, name: t?.name ?? m.name, period: t?.period ?? m.period,
                            summary: t?.summary ?? m.summary, cover: cover, description: t?.description ?? m.description)
        }
        return ContentBundle(movements: shown, artworks: artworks)
    }
}

/// The translations of the online catalog in one language (Supabase *_translations tables), kept on the device.
struct RemoteTranslation: Codable {
    struct ArtworkText: Codable {
        let title: String
        let artist: String
        let yearLabel: String?
        let museum: String?
        let teaser: String?
        let facts: [Fact]
    }

    let language: String
    let movements: [String: TranslatedCatalog.MovementText]
    let artworks: [String: ArtworkText]
}
