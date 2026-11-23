package com.vikstudios.artura.data

import android.content.Context
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.L
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * The online catalog (Supabase): artworks, movements, lessons and images.
 * Everything here is public, read-only data; the key below is the project's public "anon" key.
 */
object RemoteCatalog {
    const val base = "https://dsbhaddvzpswkjzqskhv.supabase.co"
    const val key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzYmhhZGR2enBzd2tqenFza2h2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyNzg1NDAsImV4cCI6MjExMDg1NDU0MH0.kUOMCn1oAb1lD-kym-GIUxZ4jv5FUJvEnFMbNsOFT44"
    private const val pageSize = 1000

    /** Address of an artwork image. `size` is "thumb", "large" or "zoom". */
    fun imageURL(slug: String, size: String) = "$base/storage/v1/object/public/artworks/$slug/$size.jpg"

    // MARK: Rows, as stored in the database

    @Serializable private data class MovementRow(
        val id: String, val name: String, val period: String? = null, val summary: String? = null, val description: String? = null)

    @Serializable private data class ArtworkRow(
        val slug: String,
        @SerialName("movement_id") val movementId: String,
        val title: String,
        val artist: String,
        val year: Int? = null,
        @SerialName("year_label") val yearLabel: String? = null,
        val museum: String? = null,
        @SerialName("zoom_width") val zoomWidth: Int? = null,
        @SerialName("zoom_height") val zoomHeight: Int? = null,
        val license: String? = null,
        @SerialName("attribution_required") val attributionRequired: Boolean? = null,
        val author: String? = null,
        val teaser: String? = null,
        @SerialName("focus_x") val focusX: Double? = null,
        @SerialName("focus_y") val focusY: Double? = null,
    )

    @Serializable private data class FactRow(
        @SerialName("artwork_slug") val artworkSlug: String,
        val statement: String,
        @SerialName("is_true") val isTrue: Boolean,
        val explanation: String? = null,
    )

    @Serializable private data class BlockRow(val type: String, val title: String? = null, val body: String? = null, val payload: Payload? = null) {
        @Serializable data class Payload(
            val spots: List<Spot>? = null, val lines: List<GuideLine>? = null, val caption: String? = null,
            val zoom: Double? = null, val anchor: List<Double>? = null)
    }

    @Serializable private data class QuizRow(
        val question: String, val options: List<String>, @SerialName("answer_index") val answerIndex: Int, val explanation: String? = null)

    @Serializable private data class ArtworkTranslationRow(
        @SerialName("artwork_slug") val artworkSlug: String, val title: String, val artist: String,
        @SerialName("year_label") val yearLabel: String? = null, val museum: String? = null, val teaser: String? = null)

    @Serializable private data class MovementTranslationRow(
        @SerialName("movement_id") val movementId: String, val name: String, val period: String? = null,
        val summary: String? = null, val description: String? = null)

    @Serializable private data class PublishedRow(@SerialName("artwork_slug") val artworkSlug: String)

    // MARK: Requests

    fun get(url: String, bearer: String = key): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20_000
        connection.readTimeout = 20_000
        connection.useCaches = false
        connection.setRequestProperty("apikey", key)
        connection.setRequestProperty("Authorization", "Bearer $bearer")
        return try {
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            status to (stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally {
            connection.disconnect()
        }
    }

    private suspend fun <T> rows(table: String, query: String, serializer: KSerializer<T>): List<T> = withContext(Dispatchers.IO) {
        val all = mutableListOf<T>()
        var offset = 0
        while (true) {
            val (status, body) = get("$base/rest/v1/$table?$query&limit=$pageSize&offset=$offset")
            if (status !in 200..299) throw IOException("HTTP $status")
            val page = AppJson.decodeFromString(ListSerializer(serializer), body)
            all += page
            if (page.size < pageSize) return@withContext all
            offset += pageSize
        }
        @Suppress("UNREACHABLE_CODE")
        all
    }

    /** Movements and artworks, with their true/false facts but without the lessons (loaded one by one). */
    suspend fun index(palettes: Map<String, List<String>>): ContentBundle = coroutineScope {
        val movementRows = async { rows("movements", "select=id,name,period,summary,description&order=sort_order", MovementRow.serializer()) }
        val artworkRows = async {
            rows("artworks",
                "select=slug,movement_id,title,artist,year,year_label,museum,zoom_width,zoom_height,license,attribution_required,author,teaser,focus_x,focus_y&order=slug",
                ArtworkRow.serializer())
        }
        val factRows = async { rows("true_false_facts", "select=artwork_slug,statement,is_true,explanation&order=artwork_slug,position", FactRow.serializer()) }

        val facts = factRows.await().groupBy { it.artworkSlug }
        val artworks = artworkRows.await().map { row ->
            val year = row.year ?: 0
            val aspect = if (row.zoomWidth != null && row.zoomHeight != null && row.zoomWidth > 0 && row.zoomHeight > 0)
                row.zoomWidth.toDouble() / row.zoomHeight else null
            val credit = if (row.attributionRequired == true) {
                val parts = listOfNotNull(plain(row.author), plain(row.license), L("via Wikimedia Commons"))
                L("Image: %@", parts.joinToString(", "))
            } else null
            Artwork(
                id = row.slug, title = row.title, artist = row.artist, year = year,
                yearLabel = row.yearLabel ?: if (year < 0) L("%@ BC", "${-year}") else "$year",
                museum = row.museum ?: "", movementId = row.movementId,
                image = imageURL(row.slug, "large"), hd = imageURL(row.slug, "zoom"),
                palette = palettes[row.slug] ?: emptyList(),
                focus = listOf(row.focusX ?: 0.5, row.focusY ?: 0.5),
                teaser = row.teaser ?: "",
                facts = (facts[row.slug] ?: emptyList()).map { Fact(it.statement, it.isTrue, it.explanation ?: "") },
                aspect = aspect, credit = credit,
            )
        }
        val covers = LinkedHashMap<String, String>()
        artworks.forEach { covers.putIfAbsent(it.movementId, it.id) }
        val movements = movementRows.await().mapNotNull { row ->
            val cover = covers[row.id] ?: return@mapNotNull null
            Movement(row.id, row.name, row.period ?: "", row.summary ?: "", cover, row.description ?: "")
        }
        ContentBundle(movements, artworks)
    }

    private fun blocks(rows: List<BlockRow>) = rows.map { row ->
        LessonBlock(type = row.type, title = row.title, text = row.body, caption = row.payload?.caption,
            zoom = row.payload?.zoom, anchor = row.payload?.anchor, spots = row.payload?.spots, lines = row.payload?.lines)
    }

    private fun quiz(rows: List<QuizRow>) = rows.map { QuizQuestion(it.question, it.options, it.answerIndex, it.explanation ?: "") }

    /** The lesson and quiz of one artwork. */
    suspend fun lesson(slug: String): LessonContent = coroutineScope {
        val filter = "artwork_slug=eq.$slug&order=position"
        val b = async { rows("lesson_blocks", "select=type,title,body,payload&$filter", BlockRow.serializer()) }
        val q = async { rows("quiz_questions", "select=question,options,answer_index,explanation&$filter", QuizRow.serializer()) }
        val lesson = blocks(b.await())
        if (lesson.isEmpty()) throw IOException("No lesson")
        LessonContent(lesson, quiz(q.await()))
    }

    /** Titles, movements and true/false facts of the published translated lessons in one language. */
    suspend fun translations(language: String): RemoteTranslation = coroutineScope {
        val filter = "language=eq.$language"
        val published = async { rows("lesson_translations", "select=artwork_slug&$filter", PublishedRow.serializer()) }
        val artworkRows = async { rows("artwork_translations", "select=artwork_slug,title,artist,year_label,museum,teaser&$filter", ArtworkTranslationRow.serializer()) }
        val movementRows = async { rows("movement_translations", "select=movement_id,name,period,summary,description&$filter", MovementTranslationRow.serializer()) }
        val factRows = async {
            rows("true_false_fact_translations", "select=artwork_slug,statement,is_true,explanation&$filter&order=artwork_slug,position", FactRow.serializer())
        }
        val shown = published.await().map { it.artworkSlug }.toSet()
        val facts = factRows.await().groupBy { it.artworkSlug }
        val artworks = artworkRows.await().filter { it.artworkSlug in shown }.associate { row ->
            row.artworkSlug to RemoteTranslation.ArtworkText(
                row.title, row.artist, row.yearLabel, row.museum, row.teaser,
                (facts[row.artworkSlug] ?: emptyList()).map { Fact(it.statement, it.isTrue, it.explanation ?: "") })
        }
        val movements = movementRows.await().associate {
            it.movementId to TranslatedCatalog.MovementText(it.name, it.period, it.summary, it.description)
        }
        RemoteTranslation(language, movements, artworks)
    }

    /** The translated lesson and quiz of one artwork. */
    suspend fun translatedLesson(slug: String, language: String): LessonContent = coroutineScope {
        val filter = "artwork_slug=eq.$slug&language=eq.$language&order=position"
        val b = async { rows("lesson_block_translations", "select=type,title,body,payload&$filter", BlockRow.serializer()) }
        val q = async { rows("quiz_question_translations", "select=question,options,answer_index,explanation&$filter", QuizRow.serializer()) }
        val lesson = blocks(b.await())
        if (lesson.isEmpty()) throw IOException("No lesson")
        LessonContent(lesson, quiz(q.await()))
    }

    /** Text without HTML tags (some Commons author fields contain links). */
    private fun plain(text: String?): String? {
        val stripped = text?.replace(Regex("<[^>]+>"), "")?.trim() ?: return null
        return stripped.ifEmpty { null }
    }
}

/** Copy of the online catalog kept on the device, so the app opens instantly and works offline. */
object CatalogCache {
    private lateinit var folder: File

    fun init(context: Context) {
        folder = File(context.filesDir, "Catalog").apply { File(this, "lessons").mkdirs() }
    }

    private val indexFile get() = File(folder, "index.json")
    private fun lessonFile(slug: String) = File(File(folder, "lessons"), "$slug.json")
    private val translationFile get() = File(folder, "translation.${AppLanguage.code}.json")

    private fun <T> read(file: File, serializer: KSerializer<T>): T? = try {
        if (file.exists()) AppJson.decodeFromString(serializer, file.readText()) else null
    } catch (_: Exception) { null }

    private fun <T> write(file: File, serializer: KSerializer<T>, value: T) {
        try {
            val tmp = File(file.parentFile, file.name + ".tmp")
            tmp.writeText(AppJson.encodeToString(serializer, value))
            tmp.renameTo(file)
        } catch (_: Exception) {}
    }

    fun loadIndex(): ContentBundle? = read(indexFile, ContentBundle.serializer())
    fun saveIndex(bundle: ContentBundle) = write(indexFile, ContentBundle.serializer(), bundle)

    /** Age of the saved catalog, in seconds (null if there is none). */
    val indexAge: Long? get() = if (indexFile.exists()) (System.currentTimeMillis() - indexFile.lastModified()) / 1000 else null

    fun loadTranslation(): RemoteTranslation? =
        if (AppLanguage.isEnglish) null else read(translationFile, RemoteTranslation.serializer())
    fun saveTranslation(translation: RemoteTranslation) = write(translationFile, RemoteTranslation.serializer(), translation)

    fun loadLesson(slug: String): LessonContent? = read(lessonFile(slug), LessonContent.serializer())
    fun saveLesson(content: LessonContent, slug: String) = write(lessonFile(slug), LessonContent.serializer(), content)

    /** Slugs of the lessons already saved on the device. */
    val savedLessons: List<String>
        get() = File(folder, "lessons").listFiles().orEmpty().filter { it.name.endsWith(".json") }.map { it.name.removeSuffix(".json") }

    val paletteSerializer = MapSerializer(String.serializer(), ListSerializer(String.serializer()))
}
