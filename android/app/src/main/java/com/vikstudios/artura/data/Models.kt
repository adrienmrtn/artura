package com.vikstudios.artura.data

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.hexColor
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** JSON settings shared by the whole app (same field names as the iOS Codable types). */
val AppJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    coerceInputValues = true
}

/** A point of interest on the painting, in 0…1 coordinates from the top-left corner. */
@Serializable
data class Spot(
    val x: Double,
    val y: Double,
    val zoom: Double? = null,
    /** Marker radius, as a fraction of the painting's width. */
    val r: Double? = null,
    /** "circle" (default), "rect" or "arrow" */
    val shape: String? = null,
    val title: String? = null,
    val text: String? = null,
)

/** A line drawn over the painting (composition, gaze, light). */
@Serializable
data class GuideLine(
    val points: List<List<Double>>,
    val closed: Boolean? = null,
    val label: String,
    val text: String,
)

/** A palette color, with the image that highlights the areas where it appears. */
@Serializable
data class Swatch(val hex: String, val name: String, val text: String, val image: String)

@Serializable
data class LessonBlock(
    /** Reading blocks: "text", "image", "key", "fact". Interactive, full screen on the painting: "tour", "find", "lines", "palette", "explore". */
    val type: String,
    val title: String? = null,
    val text: String? = null,
    val caption: String? = null,
    val zoom: Double? = null,
    val anchor: List<Double>? = null,
    val spots: List<Spot>? = null,
    val lines: List<GuideLine>? = null,
    val swatches: List<Swatch>? = null,
) {
    val isInteractive: Boolean get() = type in listOf("tour", "find", "lines", "palette", "explore")

    val interactiveTitle: String
        get() = title ?: when (type) {
            "tour" -> L("Guided tour")
            "find" -> L("Find it")
            "lines" -> L("Composition lines")
            "palette" -> L("The palette")
            else -> L("Free zoom")
        }

    /** Unit point (0…1) the image is zoomed on. */
    val unitAnchor: Offset
        get() = if (anchor != null && anchor.size == 2) Offset(anchor[0].toFloat(), anchor[1].toFloat()) else Offset(0.5f, 0.5f)
}

@Serializable
data class QuizQuestion(val question: String, val options: List<String>, val answer: Int, val explanation: String)

@Serializable
data class Fact(val text: String, val isTrue: Boolean, val explanation: String)

@Serializable
data class Artwork(
    val id: String,
    val title: String,
    val artist: String,
    val year: Int,
    val yearLabel: String,
    val museum: String,
    val movementId: String,
    /** Drawable name (bundled) or https address (online catalog). */
    val image: String,
    /** High-definition version, for zooming in the lesson (falls back to `image`). */
    val hd: String? = null,
    val palette: List<String> = emptyList(),
    val focus: List<Double> = listOf(0.5, 0.5),
    val teaser: String = "",
    val lesson: List<LessonBlock> = emptyList(),
    val quiz: List<QuizQuestion> = emptyList(),
    val facts: List<Fact> = emptyList(),
    /** Width / height of the picture. Known for the online catalog. */
    val aspect: Double? = null,
    /** Credit line to show with the image, when its license asks for one. */
    val credit: String? = null,
) {
    val focusPoint: Offset
        get() = if (focus.size == 2) Offset(focus[0].toFloat(), focus[1].toFloat()) else Offset(0.5f, 0.5f)

    val paletteColors: List<Color> get() = palette.map { hexColor(it) }
    val meta: String get() = "$artist · $yearLabel"
    val canvasImage: String get() = hd ?: image
    /** True when the images are downloaded (online catalog) instead of bundled with the app. */
    val isRemote: Boolean get() = image.startsWith("http")

    /** Lesson extract for the onboarding: the start, up to the first interaction, then the reading that follows up to the first "key". */
    val previewLesson: List<LessonBlock>
        get() {
            val first = lesson.indexOfFirst { it.isInteractive }
            if (first < 0) return lesson.take(4)
            var end = first
            for (i in (first + 1) until lesson.size) {
                if (lesson[i].isInteractive) break
                end = i
                if (lesson[i].type == "key") break
            }
            return lesson.subList(0, end + 1)
        }
}

@Serializable
data class Movement(
    val id: String,
    val name: String,
    val period: String,
    val summary: String,
    val cover: String,
    val description: String,
)

@Serializable
data class ContentBundle(val movements: List<Movement>, val artworks: List<Artwork>)

/** What is downloaded when a lesson is opened. */
@Serializable
data class LessonContent(val lesson: List<LessonBlock>, val quiz: List<QuizQuestion>)

val avatarImages = listOf("ill_av1", "ill_av2", "ill_av3", "ill_av4", "ill_av5")
val avatarLabels: List<String>
    get() = listOf(L("Girl with the turban"), L("Man in the straw hat"), L("Cat in a beret"), L("The sun"), L("The moon"))

/**
 * The catalog in the app's language, when it is not English: the translated lessons bundled with the app
 * (assets lessons.<code>.json). Only the translated artworks are shown in that language.
 */
@Serializable
data class TranslatedCatalog(
    val movements: Map<String, MovementText> = emptyMap(),
    val lessons: Map<String, Lesson> = emptyMap(),
) {
    @Serializable
    data class Meta(val title: String, val artist: String, val year_label: String? = null, val museum: String? = null)

    @Serializable
    data class Lesson(
        val teaser: String,
        val lesson: List<LessonBlock>,
        val quiz: List<QuizQuestion>,
        val facts: List<Fact>,
        val meta: Meta,
    )

    @Serializable
    data class MovementText(val name: String, val period: String? = null, val summary: String? = null, val description: String? = null)

    /** The online catalog restricted to the translated artworks, with their text in the app's language. */
    fun applied(bundle: ContentBundle, online: RemoteTranslation?): ContentBundle {
        val artworks = bundle.artworks.mapNotNull { a ->
            val local = lessons[a.id]
            val remote = online?.artworks?.get(a.id)
            val title = remote?.title ?: local?.meta?.title ?: return@mapNotNull null
            val artist = remote?.artist ?: local?.meta?.artist ?: return@mapNotNull null
            val facts = if (remote != null) remote.facts.ifEmpty { local?.facts ?: emptyList() } else local?.facts ?: emptyList()
            a.copy(
                title = title, artist = artist,
                yearLabel = remote?.yearLabel ?: local?.meta?.year_label ?: a.yearLabel,
                museum = remote?.museum ?: local?.meta?.museum ?: a.museum,
                teaser = remote?.teaser ?: local?.teaser ?: a.teaser,
                lesson = local?.lesson ?: emptyList(), quiz = local?.quiz ?: emptyList(), facts = facts,
            )
        }
        if (artworks.isEmpty()) return bundle
        val covers = LinkedHashMap<String, String>()
        artworks.forEach { covers.putIfAbsent(it.movementId, it.id) }
        val texts = movements.toMutableMap()
        online?.movements?.forEach { (id, t) -> texts[id] = t }
        val shown = bundle.movements.mapNotNull { m ->
            val cover = covers[m.id] ?: return@mapNotNull null
            val t = texts[m.id]
            Movement(m.id, t?.name ?: m.name, t?.period ?: m.period, t?.summary ?: m.summary, cover, t?.description ?: m.description)
        }
        return ContentBundle(shown, artworks)
    }
}

/** The translations of the online catalog in one language (Supabase *_translations tables), kept on the device. */
@Serializable
data class RemoteTranslation(
    val language: String,
    val movements: Map<String, TranslatedCatalog.MovementText>,
    val artworks: Map<String, ArtworkText>,
) {
    @Serializable
    data class ArtworkText(
        val title: String,
        val artist: String,
        val yearLabel: String? = null,
        val museum: String? = null,
        val teaser: String? = null,
        val facts: List<Fact>,
    )
}
