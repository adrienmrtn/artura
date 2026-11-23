package com.vikstudios.artura.core

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Locale

/**
 * Interface text in the app's language. The key is the English text, exactly as on iOS; the
 * translations are the iOS `Localizable.strings` files (copied to assets/i18n at build time).
 * A missing translation shows the English.
 */
fun L(english: String): String = AppLanguage.translate(english)

/**
 * Same, with values: the key uses `%@` for each value, in order (translations may reorder with
 * `%1$@`, `%2$@`). Pass every value already formatted as text: `L("%@ lessons", "$count")`.
 */
fun L(english: String, vararg values: String): String = formatIos(AppLanguage.translate(english), values.toList())

/** Applies iOS-style `%@` / `%1$@` / `%%` placeholders. */
fun formatIos(format: String, values: List<String>): String {
    val out = StringBuilder()
    var next = 0
    var i = 0
    while (i < format.length) {
        val c = format[i]
        if (c != '%' || i + 1 >= format.length) { out.append(c); i++; continue }
        val n = format[i + 1]
        when {
            n == '%' -> { out.append('%'); i += 2 }
            n == '@' -> { out.append(values.getOrElse(next) { "" }); next++; i += 2 }
            n.isDigit() -> {
                var j = i + 1
                while (j < format.length && format[j].isDigit()) j++
                if (j + 1 < format.length && format[j] == '$' && format[j + 1] == '@') {
                    val index = format.substring(i + 1, j).toInt() - 1
                    out.append(values.getOrElse(index) { "" })
                    i = j + 2
                } else { out.append(c); i++ }
            }
            else -> { out.append(c); i++ }
        }
    }
    return out.toString()
}

object AppLanguage {
    /** The app's languages, in the order of the language lists. */
    val all = listOf("en", "fr", "es", "de", "pt-BR", "pt-PT", "it", "tr", "pl", "ro", "nl", "el", "sv", "hu", "bg",
        "cs", "da", "nb", "ru", "hr", "sl", "sk", "sr-Latn", "ar", "he", "fi", "et", "lt", "lv", "ja")

    private const val prefsKey = "artura.language"
    private lateinit var app: Context
    private var table: Map<String, String> = emptyMap()

    /** Current language: "en", "fr", "pt-BR", "sr-Latn"… Observable: the UI is rebuilt when it changes. */
    var code by mutableStateOf("en")
        private set

    /** Listeners called after a change from inside the app (the content store reloads). */
    private val listeners = mutableListOf<(from: String, to: String) -> Unit>()

    fun init(context: Context) {
        app = context.applicationContext
        val saved = app.getSharedPreferences("artura", Context.MODE_PRIVATE).getString(prefsKey, null)
        code = saved?.takeIf { it in all } ?: match(Locale.getDefault())
        table = load(code)
    }

    /** The phone's language, matched to one of the app's languages (English otherwise). */
    fun match(locale: Locale): String {
        val lang = locale.language
        val tag = locale.toLanguageTag()
        return when {
            lang == "pt" -> if (locale.country == "BR") "pt-BR" else "pt-PT"
            lang == "sr" -> "sr-Latn"
            lang == "no" || lang == "nb" || lang == "nn" -> "nb"
            lang == "iw" -> "he"
            all.contains(tag) -> tag
            all.contains(lang) -> lang
            else -> "en"
        }
    }

    val isEnglish: Boolean get() = code == "en" || code.startsWith("en-")

    /** For dates and numbers in the app's language. */
    val locale: Locale get() = Locale.forLanguageTag(code)

    /** Right-to-left interface (Arabic, Hebrew). */
    val isRightToLeft: Boolean get() = code == "ar" || code == "he"

    /** Name of a language in that language: "Français", "Deutsch", "日本語"… */
    fun name(language: String): String {
        val own = Locale.forLanguageTag(language)
        val name = own.getDisplayName(own).ifEmpty { language }
        return name.replaceFirstChar { it.titlecase(own) }
    }

    fun addListener(listener: (String, String) -> Unit) { listeners += listener }

    /** Switches the whole app to `language` now, and keeps it for the next launches. */
    fun set(language: String) {
        if (language !in all || language == code) return
        val from = code
        table = load(language)
        code = language
        app.getSharedPreferences("artura", Context.MODE_PRIVATE).edit().putString(prefsKey, language).apply()
        listeners.forEach { it(from, language) }
    }

    fun translate(english: String): String {
        table[english]?.let { return it }
        // Android-only texts that name the store: reuse the iOS translation and swap the store's name.
        storeKeys[english]?.let { ios -> table[ios]?.let { return toGooglePlay(it) } }
        return english
    }

    /** Android key → iOS key of the same sentence about the App Store. */
    private val storeKeys = mapOf(
        "Secured with Google Play" to "Secured with App Store",
        "on Google Play" to "on the App Store",
        "More than %@ learners, rated %@ out of 5 on Google Play" to "More than %@ learners, rated %@ out of 5 on the App Store",
    )

    private fun toGooglePlay(text: String): String = text
        .replace("l'App Store", "Google Play").replace("l’App Store", "Google Play")
        .replace("App Store", "Google Play")

    /** A context whose resources use the app's language (system dialogs, formatting). */
    fun wrap(context: Context): Context {
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    /** Name of a bundled asset for the current language, falling back to English: `content.fr.json`, then `content.json`. */
    fun resource(name: String, ext: String): String {
        if (!isEnglish) {
            val localized = "$name.$code.$ext"
            if (assetExists(localized)) return localized
        }
        return "$name.$ext"
    }

    fun assetExists(path: String): Boolean = try {
        app.assets.open(path).close(); true
    } catch (_: Exception) { false }

    private fun load(language: String): Map<String, String> = loadStrings(app, "i18n/$language.strings")

    /** Parses an iOS `.strings` file: `"key" = "value";` lines, with `\"`, `\\` and `\n` escapes. */
    fun loadStrings(context: Context, path: String): Map<String, String> {
        val text = try {
            context.assets.open(path).bufferedReader().use { it.readText() }
        } catch (_: Exception) { return emptyMap() }
        val map = HashMap<String, String>(1024)
        var i = 0
        fun readQuoted(): String? {
            while (i < text.length && text[i] != '"') {
                if (text.startsWith("/*", i)) { val end = text.indexOf("*/", i + 2); i = if (end < 0) text.length else end + 2; continue }
                if (text.startsWith("//", i)) { val end = text.indexOf('\n', i); i = if (end < 0) text.length else end + 1; continue }
                if (text[i] == ';' || text[i] == '=' || text[i].isWhitespace()) { i++; continue }
                i++
            }
            if (i >= text.length) return null
            i++
            val sb = StringBuilder()
            while (i < text.length && text[i] != '"') {
                val ch = text[i]
                if (ch == '\\' && i + 1 < text.length) {
                    when (val e = text[i + 1]) {
                        'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r')
                        else -> sb.append(e)
                    }
                    i += 2
                } else { sb.append(ch); i++ }
            }
            i++
            return sb.toString()
        }
        while (i < text.length) {
            val key = readQuoted() ?: break
            val value = readQuoted() ?: break
            map[key] = value
        }
        return map
    }
}
