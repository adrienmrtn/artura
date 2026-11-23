package com.vikstudios.artura.review

import androidx.compose.ui.geometry.Offset
import com.vikstudios.artura.core.L
import com.vikstudios.artura.data.Artwork
import java.util.UUID

/** One question of a review or practice session. */
data class ReviewCard(
    /** Short label shown above the question ("From the lesson", "True or false"…). */
    val kind: String,
    val prompt: String,
    val image: String? = null,
    val anchor: Offset = Offset(0.5f, 0.5f),
    /** Statement to judge, for true/false questions. */
    val statement: String? = null,
    val choices: List<Choice>,
    val correct: String,
    val explanation: String,
    val id: String = UUID.randomUUID().toString(),
) {
    data class Choice(val id: String, val title: String)
}

/** A set of questions drawn from a group of artworks. */
data class ReviewDeck(
    val title: String,
    val cards: List<ReviewCard>,
    /** True for the daily review, which counts once a day. */
    val daily: Boolean = false,
    val id: String = UUID.randomUUID().toString(),
) {
    companion object {
        /** Number of cards in the daily review. */
        const val DAILY_SIZE = 10

        /** Today's review: questions drawn from the lessons already read. */
        fun daily(artworks: List<Artwork>, all: List<Artwork>) =
            ReviewDeck(L("Today's review"), cards(artworks, all, DAILY_SIZE), daily = true)

        /** Free practice on a chosen group of artworks. */
        fun practice(title: String, artworks: List<Artwork>, all: List<Artwork>, limit: Int = 12) =
            ReviewDeck(title, cards(artworks, all, limit))

        /** How many cards a group of artworks can produce (used to enable or disable the buttons). */
        fun available(artworks: List<Artwork>, all: List<Artwork>): Int = pool(artworks, all).size

        private fun cards(artworks: List<Artwork>, all: List<Artwork>, limit: Int) = pool(artworks, all).shuffled().take(limit)

        /** Every question that can be asked about these artworks. `all` supplies the wrong answers. */
        private fun pool(artworks: List<Artwork>, all: List<Artwork>): List<ReviewCard> {
            val cards = mutableListOf<ReviewCard>()
            val artists = all.map { it.artist }.toSet().toList()

            for (art in artworks) {
                // Questions written for the lesson's own quiz.
                for (q in art.quiz) {
                    if (q.answer !in q.options.indices) continue
                    cards += ReviewCard(
                        kind = L("From the lesson"), prompt = q.question, image = art.image, anchor = art.focusPoint,
                        choices = q.options.mapIndexed { i, o -> ReviewCard.Choice("$i", o) },
                        correct = "${q.answer}", explanation = q.explanation,
                    )
                }

                // Studio stories, true or false.
                for (fact in art.facts) {
                    cards += ReviewCard(
                        kind = L("True or false"), prompt = L("True or false?"), image = art.image, anchor = art.focusPoint,
                        statement = fact.text,
                        choices = listOf(ReviewCard.Choice("true", L("True")), ReviewCard.Choice("false", L("False"))),
                        correct = if (fact.isTrue) "true" else "false", explanation = fact.explanation,
                    )
                }

                // Name the artwork.
                val otherTitles = all.filter { it.id != art.id }.shuffled().take(3)
                if (otherTitles.size == 3) {
                    val options = (otherTitles + art).shuffled()
                    cards += ReviewCard(
                        kind = L("Name it"), prompt = L("What is this artwork called?"), image = art.image, anchor = art.focusPoint,
                        choices = options.map { ReviewCard.Choice(it.id, it.title) },
                        correct = art.id, explanation = L("%@, by %@ (%@).", art.title, art.artist, art.yearLabel),
                    )
                }

                // Name the artist.
                val otherArtists = artists.filter { it != art.artist }.shuffled().take(3)
                if (otherArtists.size == 3) {
                    val options = (otherArtists + art.artist).shuffled()
                    cards += ReviewCard(
                        kind = L("Who made it?"), prompt = L("Who made this artwork?"), image = art.image, anchor = art.focusPoint,
                        choices = options.map { ReviewCard.Choice(it, it) },
                        correct = art.artist, explanation = L("%@ is by %@, %@.", art.title, art.artist, art.museum),
                    )
                }
            }
            return cards
        }
    }
}
