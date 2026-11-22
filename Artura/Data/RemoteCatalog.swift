import SwiftUI
import UIKit

/// The online catalog (Supabase): artworks, movements, lessons and images.
/// Everything here is public, read-only data; the key below is the project's public "anon" key.
enum RemoteCatalog {
    static let base = "https://dsbhaddvzpswkjzqskhv.supabase.co"
    private static let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzYmhhZGR2enBzd2tqenFza2h2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyNzg1NDAsImV4cCI6MjExMDg1NDU0MH0.kUOMCn1oAb1lD-kym-GIUxZ4jv5FUJvEnFMbNsOFT44"
    private static let pageSize = 1000

    /// Address of an artwork image. `size` is "thumb", "large" or "zoom".
    static func imageURL(_ slug: String, _ size: String) -> String {
        "\(base)/storage/v1/object/public/artworks/\(slug)/\(size).jpg"
    }

    // MARK: Rows, as stored in the database

    private struct MovementRow: Decodable {
        let id: String
        let name: String
        let period: String?
        let summary: String?
        let description: String?
    }

    private struct ArtworkRow: Decodable {
        let slug: String
        let movementId: String
        let title: String
        let artist: String
        let year: Int?
        let yearLabel: String?
        let museum: String?
        let zoomWidth: Int?
        let zoomHeight: Int?
        let license: String?
        let attributionRequired: Bool?
        let author: String?
        let teaser: String?
        let focusX: Double?
        let focusY: Double?
    }

    private struct FactRow: Decodable {
        let artworkSlug: String
        let statement: String
        let isTrue: Bool
        let explanation: String?
    }

    private struct BlockRow: Decodable {
        struct Payload: Decodable {
            let spots: [Spot]?
            let lines: [GuideLine]?
            let caption: String?
            let zoom: Double?
            let anchor: [Double]?
        }
        let type: String
        let title: String?
        let body: String?
        let payload: Payload?
    }

    private struct QuizRow: Decodable {
        let question: String
        let options: [String]
        let answerIndex: Int
        let explanation: String?
    }

    // MARK: Requests

    private static func rows<T: Decodable>(_ table: String, _ query: String) async throws -> [T] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var all: [T] = []
        var offset = 0
        while true {
            guard let url = URL(string: "\(base)/rest/v1/\(table)?\(query)&limit=\(pageSize)&offset=\(offset)") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue(key, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let page = try decoder.decode([T].self, from: data)
            all += page
            if page.count < pageSize { return all }
            offset += pageSize
        }
    }

    /// Movements and artworks, with their true/false facts but without the lessons (loaded one by one).
    static func index(palettes: [String: [String]]) async throws -> ContentBundle {
        async let movementRows: [MovementRow] = rows(
            "movements", "select=id,name,period,summary,description&order=sort_order")
        async let artworkRows: [ArtworkRow] = rows(
            "artworks",
            "select=slug,movement_id,title,artist,year,year_label,museum,zoom_width,zoom_height,license,attribution_required,author,teaser,focus_x,focus_y&order=slug")
        async let factRows: [FactRow] = rows(
            "true_false_facts", "select=artwork_slug,statement,is_true,explanation&order=artwork_slug,position")

        let facts = Dictionary(grouping: try await factRows, by: \.artworkSlug)
        let artworks = try await artworkRows.map { row -> Artwork in
            let year = row.year ?? 0
            var aspect: Double?
            if let w = row.zoomWidth, let h = row.zoomHeight, w > 0, h > 0 { aspect = Double(w) / Double(h) }
            var credit: String?
            if row.attributionRequired == true {
                let parts = [plain(row.author), plain(row.license), "via Wikimedia Commons"].compactMap { $0 }
                credit = "Image: " + parts.joined(separator: ", ")
            }
            return Artwork(
                id: row.slug, title: row.title, artist: row.artist, year: year,
                yearLabel: row.yearLabel ?? (year < 0 ? "\(-year) BC" : "\(year)"),
                museum: row.museum ?? "", movementId: row.movementId,
                image: imageURL(row.slug, "large"), hd: imageURL(row.slug, "zoom"),
                palette: palettes[row.slug] ?? [],
                focus: [row.focusX ?? 0.5, row.focusY ?? 0.5],
                teaser: row.teaser ?? "",
                lesson: [], quiz: [],
                facts: (facts[row.slug] ?? []).map {
                    Fact(text: $0.statement, isTrue: $0.isTrue, explanation: $0.explanation ?? "")
                },
                aspect: aspect, credit: credit
            )
        }
        let covers = Dictionary(artworks.map { ($0.movementId, $0.id) }, uniquingKeysWith: { first, _ in first })
        let movements = try await movementRows.compactMap { row -> Movement? in
            guard let cover = covers[row.id] else { return nil }
            return Movement(id: row.id, name: row.name, period: row.period ?? "",
                            summary: row.summary ?? "", cover: cover, description: row.description ?? "")
        }
        return ContentBundle(movements: movements, artworks: artworks)
    }

    /// The lesson and quiz of one artwork.
    static func lesson(_ slug: String) async throws -> LessonContent {
        let filter = "artwork_slug=eq.\(slug)&order=position"
        async let blockRows: [BlockRow] = rows("lesson_blocks", "select=type,title,body,payload&\(filter)")
        async let quizRows: [QuizRow] = rows("quiz_questions", "select=question,options,answer_index,explanation&\(filter)")
        let blocks = try await blockRows.map { row in
            LessonBlock(type: row.type, title: row.title, text: row.body,
                        caption: row.payload?.caption, zoom: row.payload?.zoom, anchor: row.payload?.anchor,
                        spots: row.payload?.spots, lines: row.payload?.lines, swatches: nil)
        }
        let quiz = try await quizRows.map {
            QuizQuestion(question: $0.question, options: $0.options, answer: $0.answerIndex,
                         explanation: $0.explanation ?? "")
        }
        guard !blocks.isEmpty else { throw URLError(.resourceUnavailable) }
        return LessonContent(lesson: blocks, quiz: quiz)
    }

    /// Text without HTML tags (some Commons author fields contain links).
    private static func plain(_ text: String?) -> String? {
        guard let text else { return nil }
        let stripped = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}

/// What is downloaded when a lesson is opened.
struct LessonContent: Codable {
    let lesson: [LessonBlock]
    let quiz: [QuizQuestion]
}

/// Copy of the online catalog kept on the device, so the app opens instantly and works offline.
enum CatalogCache {
    private static var folder: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = base.appendingPathComponent("Catalog", isDirectory: true)
        try? FileManager.default.createDirectory(at: url.appendingPathComponent("lessons", isDirectory: true),
                                                 withIntermediateDirectories: true)
        return url
    }

    private static var indexURL: URL? { folder?.appendingPathComponent("index.json") }

    private static func lessonURL(_ slug: String) -> URL? {
        folder?.appendingPathComponent("lessons", isDirectory: true).appendingPathComponent("\(slug).json")
    }

    static func loadIndex() -> ContentBundle? {
        guard let url = indexURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ContentBundle.self, from: data)
    }

    static func saveIndex(_ bundle: ContentBundle) {
        guard let url = indexURL, let data = try? JSONEncoder().encode(bundle) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Age of the saved catalog, in seconds (nil if there is none).
    static var indexAge: TimeInterval? {
        guard let url = indexURL,
              let date = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        else { return nil }
        return Date().timeIntervalSince(date)
    }

    static func loadLesson(_ slug: String) -> LessonContent? {
        guard let url = lessonURL(slug), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LessonContent.self, from: data)
    }

    static func saveLesson(_ content: LessonContent, slug: String) {
        guard let url = lessonURL(slug), let data = try? JSONEncoder().encode(content) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Slugs of the lessons already saved on the device.
    static var savedLessons: [String] {
        guard let folder = folder?.appendingPathComponent("lessons", isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }
    }
}

// MARK: - Images

/// Downloads the catalog images and keeps them in memory and on disk.
final class ImageStore {
    static let shared = ImageStore()

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        memory.totalCostLimit = 160 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 600 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func cached(_ url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    func load(_ url: String) async -> UIImage? {
        if let image = cached(url) { return image }
        guard let address = URL(string: url),
              let (data, response) = try? await session.data(from: address),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = UIImage(data: data) else { return nil }
        let image = await decoded.byPreparingForDisplay() ?? decoded
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        memory.setObject(image, forKey: url as NSString, cost: cost)
        return image
    }
}

/// An image of the online catalog. Shows a soft tint, then fades the picture in.
struct RemoteImage: View {
    let url: String
    /// Shown while `url` loads, if it is already in memory (a smaller version of the same picture).
    var placeholder: String? = nil
    /// True to fill the frame and crop; false to stretch to the frame (same proportions as the picture).
    var fill = true

    @State private var image: UIImage?

    var body: some View {
        Palette.card
            .overlay {
                if let shown = image ?? ImageStore.shared.cached(url) ?? placeholder.flatMap({ ImageStore.shared.cached($0) }) {
                    if fill {
                        Image(uiImage: shown).resizable().scaledToFill().transition(.opacity)
                    } else {
                        Image(uiImage: shown).resizable().transition(.opacity)
                    }
                }
            }
            .clipped()
            .task(id: url) {
                if let ready = ImageStore.shared.cached(url) {
                    image = ready
                    return
                }
                image = nil
                let loaded = await ImageStore.shared.load(url)
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.25)) { image = loaded }
            }
    }
}
