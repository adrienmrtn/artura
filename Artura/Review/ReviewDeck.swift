import SwiftUI

/// One question of a review or practice session.
struct ReviewCard: Identifiable {
    struct Choice: Identifiable {
        let id: String
        let title: String
    }

    let id = UUID()
    /// Short label shown above the question ("From the lesson", "True or false"…).
    let kind: String
    let prompt: String
    var image: String? = nil
    var anchor: UnitPoint = .center
    /// Statement to judge, for true/false questions.
    var statement: String? = nil
    let choices: [Choice]
    let correct: String
    let explanation: String
}

/// A set of questions drawn from a group of artworks.
struct ReviewDeck: Identifiable {
    let id = UUID()
    let title: String
    let cards: [ReviewCard]
    /// True for the daily review, which counts once a day.
    var daily = false

    /// Number of cards in the daily review.
    static let dailySize = 10

    /// Today's review: questions drawn from the lessons already read.
    static func daily(artworks: [Artwork], all: [Artwork]) -> ReviewDeck {
        ReviewDeck(title: L("Today's review"),
                   cards: cards(from: artworks, all: all, limit: dailySize),
                   daily: true)
    }

    /// Free practice on a chosen group of artworks.
    static func practice(title: String, artworks: [Artwork], all: [Artwork], limit: Int = 12) -> ReviewDeck {
        ReviewDeck(title: title, cards: cards(from: artworks, all: all, limit: limit))
    }

    /// How many cards a group of artworks can produce (used to enable or disable the buttons).
    static func available(from artworks: [Artwork], all: [Artwork]) -> Int {
        pool(from: artworks, all: all).count
    }

    private static func cards(from artworks: [Artwork], all: [Artwork], limit: Int) -> [ReviewCard] {
        Array(pool(from: artworks, all: all).shuffled().prefix(limit))
    }

    /// Every question that can be asked about these artworks. `all` supplies the wrong answers.
    private static func pool(from artworks: [Artwork], all: [Artwork]) -> [ReviewCard] {
        var cards: [ReviewCard] = []
        let artists = Array(Set(all.map(\.artist)))

        for art in artworks {
            // Questions written for the lesson's own quiz.
            for question in art.quiz where question.options.indices.contains(question.answer) {
                cards.append(ReviewCard(
                    kind: L("From the lesson"), prompt: question.question, image: art.image, anchor: art.focusPoint,
                    choices: question.options.enumerated().map { ReviewCard.Choice(id: "\($0.offset)", title: $0.element) },
                    correct: "\(question.answer)", explanation: question.explanation
                ))
            }

            // Studio stories, true or false.
            for fact in art.facts {
                cards.append(ReviewCard(
                    kind: L("True or false"), prompt: L("True or false?"), image: art.image, anchor: art.focusPoint,
                    statement: fact.text,
                    choices: [ReviewCard.Choice(id: "true", title: L("True")), ReviewCard.Choice(id: "false", title: L("False"))],
                    correct: fact.isTrue ? "true" : "false", explanation: fact.explanation
                ))
            }

            // Name the artwork.
            let otherTitles = all.filter { $0.id != art.id }.shuffled().prefix(3)
            if otherTitles.count == 3 {
                let options = (otherTitles + [art]).shuffled()
                cards.append(ReviewCard(
                    kind: L("Name it"), prompt: L("What is this artwork called?"), image: art.image, anchor: art.focusPoint,
                    choices: options.map { ReviewCard.Choice(id: $0.id, title: $0.title) },
                    correct: art.id, explanation: L("%@, by %@ (%@).", art.title, art.artist, art.yearLabel)
                ))
            }

            // Name the artist.
            let otherArtists = artists.filter { $0 != art.artist }.shuffled().prefix(3)
            if otherArtists.count == 3 {
                let options = (otherArtists + [art.artist]).shuffled()
                cards.append(ReviewCard(
                    kind: L("Who made it?"), prompt: L("Who made this artwork?"), image: art.image, anchor: art.focusPoint,
                    choices: options.map { ReviewCard.Choice(id: $0, title: $0) },
                    correct: art.artist, explanation: L("%@ is by %@, %@.", art.title, art.artist, art.museum)
                ))
            }
        }
        return cards
    }
}
