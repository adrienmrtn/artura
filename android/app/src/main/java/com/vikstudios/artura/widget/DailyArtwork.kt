package com.vikstudios.artura.widget

import android.content.Context
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.L
import com.vikstudios.artura.data.AppJson
import com.vikstudios.artura.data.ContentStore
import kotlinx.serialization.Serializable
import java.time.LocalDate

/** The few fields the widget needs, read from the same `content.json` as the app. */
@Serializable
data class DailyArtwork(
    val id: String,
    val title: String,
    val artist: String,
    val yearLabel: String,
    val image: String,
    val teaser: String = "",
)

/** The bundled artworks, in the app's language (port of DailyArtwork.swift). */
object DailyCatalog {
    @Serializable private data class Bundle(val artworks: List<DailyArtwork>)

    private var cached: Pair<String, List<DailyArtwork>>? = null
    private var widgetStrings: Pair<String, Map<String, String>>? = null

    fun artworks(context: Context): List<DailyArtwork> {
        AppLanguage.init(context)
        cached?.let { (code, list) -> if (code == AppLanguage.code) return list }
        val list = try {
            val name = AppLanguage.resource("content", "json")
            AppJson.decodeFromString(Bundle.serializer(), context.assets.open(name).bufferedReader().use { it.readText() }).artworks
        } catch (_: Exception) { emptyList() }
        cached = AppLanguage.code to list
        return list
    }

    /** Same rule as `ContentStore.artworkOfTheDay` for the bundled content, so the widget and the feed agree. */
    fun artwork(context: Context, date: LocalDate = LocalDate.now()): DailyArtwork? {
        val list = artworks(context)
        if (list.isEmpty()) return null
        return list[(ContentStore.dayOrdinal(date) % list.size).toInt()]
    }

    /** Widget text: the widget's own translations (copied from the iOS widget .lproj folders), then the app's. */
    fun text(context: Context, english: String): String {
        AppLanguage.init(context)
        val table = widgetStrings?.takeIf { it.first == AppLanguage.code }?.second
            ?: AppLanguage.loadStrings(context, "i18n-widget/${AppLanguage.code}.strings").also { widgetStrings = AppLanguage.code to it }
        return table[english] ?: L(english)
    }
}
