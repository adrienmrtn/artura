import SwiftUI

struct LessonBlock: Codable, Hashable {
    /// "text", "image" ou "key"
    let type: String
    var text: String?
    var caption: String?
    var zoom: Double?
    var anchor: [Double]?

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

/// Contenu embarqué dans l'appli (Resources/content.json).
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
            assertionFailure("content.json introuvable ou invalide")
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

    /// Œuvre du jour : change chaque jour, de façon stable.
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
let avatarLabels = ["La jeune fille au turban", "L'homme au chapeau de paille", "Le chat au béret", "Le soleil", "La lune"]
