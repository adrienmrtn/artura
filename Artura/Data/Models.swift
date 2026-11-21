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
        case "tour": return "Guided tour"
        case "find": return "Find it"
        case "lines": return "Composition lines"
        case "palette": return "The palette"
        default: return "Free zoom"
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
    let lesson: [LessonBlock]
    let quiz: [QuizQuestion]
    let facts: [Fact]

    var focusPoint: UnitPoint {
        guard focus.count == 2 else { return .center }
        return UnitPoint(x: focus[0], y: focus[1])
    }

    var paletteColors: [Color] { palette.map { Color(hexString: $0) } }
    var meta: String { "\(artist) · \(yearLabel)" }
    var canvasImage: String { hd ?? image }
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

/// Content bundled with the app (Resources/content.json).
final class ContentStore: ObservableObject {
    let movements: [Movement]
    let artworks: [Artwork]

    init() {
        if let url = Bundle.main.url(forResource: "content", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundle = try? JSONDecoder().decode(ContentBundle.self, from: data) {
            movements = bundle.movements
            artworks = bundle.artworks
        } else {
            assertionFailure("content.json missing or invalid")
            movements = []
            artworks = []
        }
    }

    func artwork(_ id: String?) -> Artwork? {
        guard let id else { return nil }
        return artworks.first { $0.id == id }
    }

    func movement(_ id: String?) -> Movement? {
        guard let id else { return nil }
        return movements.first { $0.id == id }
    }

    func artworks(in movementId: String) -> [Artwork] {
        artworks.filter { $0.movementId == movementId }
    }

    /// Artwork of the day: changes daily, in a stable way.
    var artworkOfTheDay: Artwork? {
        guard !artworks.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return artworks[day % artworks.count]
    }

    var allFacts: [(fact: Fact, artwork: Artwork)] {
        artworks.flatMap { art in art.facts.map { (fact: $0, artwork: art) } }
    }
}

let avatarImages = ["ill_av1", "ill_av2", "ill_av3", "ill_av4", "ill_av5"]
let avatarLabels = ["Girl with the turban", "Man in the straw hat", "Cat in a beret", "The sun", "The moon"]
