package com.vikstudios.artura.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.vikstudios.artura.core.AppLanguage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * The artworks and movements shown in the app.
 * Starts with the content bundled with the app (assets content.json), then, once the main app is on
 * screen, switches to the online catalog (saved on the device after the first download).
 */
class ContentStore(private val context: Context) {
    var movements by mutableStateOf<List<Movement>>(emptyList())
        private set
    var artworks by mutableStateOf<List<Artwork>>(emptyList())
        private set

    private var bundled: ContentBundle = loadBundled()
    private var byId: Map<String, Artwork> = emptyMap()
    private var dailyOrder: List<Artwork> = emptyList()
    private var usesCatalog = false
    /** Catalog text in the app's language, downloaded (null in English or before the first download). */
    private var translation: RemoteTranslation? = null
    private var refreshing = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    init {
        replaceArtworks(bundled.artworks)
        movements = bundled.movements
    }

    private fun replaceArtworks(list: List<Artwork>) {
        artworks = list
        byId = LinkedHashMap<String, Artwork>().apply { list.forEach { putIfAbsent(it.id, it) } }
        // Stable shuffle, so the artwork of the day does not walk through the catalog alphabetically.
        dailyOrder = if (usesCatalog) list.sortedWith(compareBy { stableHash(it.id).toULong() }) else list
    }

    private fun loadBundled(): ContentBundle = try {
        val name = AppLanguage.resource("content", "json")
        AppJson.decodeFromString(ContentBundle.serializer(), context.assets.open(name).bufferedReader().use { it.readText() })
    } catch (_: Exception) {
        ContentBundle(emptyList(), emptyList())
    }

    /** The language was changed in the app: everything is shown again in the new language at once, then the online translations are downloaded. */
    fun languageChanged() {
        bundled = loadBundled()
        TranslatedCatalog.reset()
        translation = CatalogCache.loadTranslation()
        byId = emptyMap()
        val saved = CatalogCache.loadIndex()
        if (usesCatalog && saved != null && saved.artworks.isNotEmpty()) {
            apply(saved)
        } else {
            movements = bundled.movements
            replaceArtworks(bundled.artworks)
        }
        if (AppLanguage.isEnglish) return
        val language = AppLanguage.code
        scope.launch {
            val online = downloadTranslation() ?: return@launch
            if (online.artworks.isEmpty() || language != AppLanguage.code) return@launch
            withContext(Dispatchers.IO) { CatalogCache.saveTranslation(online) }
            translation = online
            val again = CatalogCache.loadIndex()
            if (usesCatalog && again != null && again.artworks.isNotEmpty()) apply(again)
        }
    }

    /** Looks in the current catalog, then in the bundled artworks (onboarding, lessons read before the catalog). */
    fun artwork(id: String?): Artwork? {
        if (id == null) return null
        return byId[id] ?: bundled.artworks.firstOrNull { it.id == id }
    }

    fun movement(id: String?): Movement? {
        if (id == null) return null
        return movements.firstOrNull { it.id == id } ?: bundled.movements.firstOrNull { it.id == id }
    }

    fun artworks(movementId: String): List<Artwork> = artworks.filter { it.movementId == movementId }

    /** Artwork of the day: changes daily, in a stable way. */
    val artworkOfTheDay: Artwork?
        get() {
            if (dailyOrder.isEmpty()) return null
            return dailyOrder[(dayOrdinal() % dailyOrder.size).toInt()]
        }

    val allFacts: List<Pair<Fact, Artwork>> get() = artworks.flatMap { art -> art.facts.map { it to art } }

    // MARK: Online catalog

    private val palettes: Map<String, List<String>> by lazy {
        try {
            AppJson.decodeFromString(CatalogCache.paletteSerializer, context.assets.open("palettes.json").bufferedReader().use { it.readText() })
        } catch (_: Exception) { emptyMap() }
    }

    /** Called when the main app appears: shows the saved catalog at once, and updates it when it is old. */
    fun activateCatalog() {
        if (!usesCatalog) {
            val saved = CatalogCache.loadIndex()
            if (saved != null && saved.artworks.isNotEmpty()) {
                translation = CatalogCache.loadTranslation()
                apply(saved)
            }
        }
        val age = CatalogCache.indexAge
        if (refreshing || !(!usesCatalog || age == null || age > 6 * 3600)) return
        refreshing = true
        scope.launch {
            try {
                val index = async(Dispatchers.IO) { runCatching { RemoteCatalog.index(palettes) }.getOrNull() }
                val texts = async(Dispatchers.IO) { downloadTranslation() }
                val fresh = index.await()
                val online = texts.await()
                if (online != null && online.artworks.isNotEmpty()) {
                    withContext(Dispatchers.IO) { CatalogCache.saveTranslation(online) }
                    translation = online
                }
                if (fresh == null || fresh.artworks.isEmpty()) return@launch
                withContext(Dispatchers.IO) { CatalogCache.saveIndex(fresh) }
                apply(fresh)
            } finally {
                refreshing = false
            }
        }
    }

    /** Replaces the catalog, keeping the lessons already on the device. */
    private fun apply(english: ContentBundle) {
        val bundle = TranslatedCatalog.current(context)?.applied(english, translation) ?: english
        val saved = CatalogCache.savedLessons.toSet()
        val list = bundle.artworks.map { a ->
            if (a.lesson.isNotEmpty()) return@map a
            val known = byId[a.id]
            if (known != null && known.lesson.isNotEmpty()) return@map a.copy(lesson = known.lesson, quiz = known.quiz)
            val key = lessonKey(a.id)
            if (key in saved) CatalogCache.loadLesson(key)?.let { return@map a.copy(lesson = it.lesson, quiz = it.quiz) }
            a
        }
        usesCatalog = true
        movements = bundle.movements
        replaceArtworks(list)
    }

    /** The artwork with its lesson and quiz, downloaded if needed. Null when it cannot be loaded. */
    suspend fun withLesson(artwork: Artwork): Artwork? {
        if (artwork.lesson.isNotEmpty()) return artwork
        byId[artwork.id]?.let { if (it.lesson.isNotEmpty()) return it }
        val downloaded = withContext(Dispatchers.IO) {
            runCatching {
                if (AppLanguage.isEnglish) RemoteCatalog.lesson(artwork.id)
                else RemoteCatalog.translatedLesson(artwork.id, AppLanguage.code)
            }.getOrNull()
        } ?: return null
        withContext(Dispatchers.IO) { CatalogCache.saveLesson(downloaded, lessonKey(artwork.id)) }
        val full = (byId[artwork.id] ?: artwork).copy(lesson = downloaded.lesson, quiz = downloaded.quiz)
        val i = artworks.indexOfFirst { it.id == full.id }
        if (i >= 0) replaceArtworks(artworks.toMutableList().also { it[i] = full })
        return full
    }

    private suspend fun downloadTranslation(): RemoteTranslation? {
        if (AppLanguage.isEnglish) return null
        return withContext(Dispatchers.IO) { runCatching { RemoteCatalog.translations(AppLanguage.code) }.getOrNull() }
    }

    /** Name of a lesson saved on the device: the slug in English, "slug.fr" in French, etc. */
    private fun lessonKey(id: String) = if (AppLanguage.isEnglish) id else "$id.${AppLanguage.code}"

    companion object {
        /** FNV-1a 64-bit, same as iOS, so the order of the days is the same on both platforms. */
        fun stableHash(text: String): Long {
            var hash = -3750763034362895579L // 14695981039346656037 as signed
            for (byte in text.toByteArray(Charsets.UTF_8)) {
                hash = hash xor (byte.toLong() and 0xFF)
                hash *= 1099511628211L
            }
            return hash
        }

        /**
         * Day number counted like iOS `Calendar.current.ordinality(of: .day, in: .era)`: day 1 is
         * 1 January of year 1 in the Julian calendar (Foundation's Gregorian calendar is Julian before
         * October 1582), which is 30 December of year 0 in the proleptic Gregorian calendar of java.time.
         */
        fun dayOrdinal(date: LocalDate = LocalDate.now()): Long =
            ChronoUnit.DAYS.between(LocalDate.of(0, 12, 30), date) + 1
    }
}

/** Bundled translations of the current language (null in English). Reloaded when the language changes. */
fun TranslatedCatalog.Companion.current(context: Context): TranslatedCatalog? {
    if (AppLanguage.isEnglish) return null
    TranslatedCatalogCache.cached?.let { (code, catalog) -> if (code == AppLanguage.code) return catalog }
    val catalog = try {
        AppJson.decodeFromString(TranslatedCatalog.serializer(),
            context.assets.open("lessons.${AppLanguage.code}.json").bufferedReader().use { it.readText() })
    } catch (_: Exception) { TranslatedCatalog() }
    TranslatedCatalogCache.cached = AppLanguage.code to catalog
    return catalog
}

fun TranslatedCatalog.Companion.reset() { TranslatedCatalogCache.cached = null }

private object TranslatedCatalogCache {
    var cached: Pair<String, TranslatedCatalog>? = null
}
