package com.vikstudios.artura.app

import android.content.Intent
import com.vikstudios.artura.BuildConfig
import com.vikstudios.artura.data.Profile

/**
 * Launch arguments (debug builds only) to open the app in a given state, for screenshots and development.
 * Same names as the iOS launch arguments, passed as intent extras:
 *
 *     adb shell am start -n com.vikstudios.artura/.app.MainActivity --es appTab review --es demoProfile YES
 */
object AppDebug {
    private var args: Map<String, String> = emptyMap()

    val isDebug: Boolean get() = BuildConfig.DEBUG

    fun read(intent: Intent?) {
        if (!BuildConfig.DEBUG || intent == null) return
        val extras = intent.extras ?: return
        args = extras.keySet().associateWith { extras.get(it)?.toString() ?: "" }
    }

    fun string(key: String): String? = if (BuildConfig.DEBUG) args[key] else null

    fun flag(key: String): Boolean {
        val v = string(key) ?: return false
        return v.equals("YES", true) || v.equals("true", true) || v == "1"
    }

    fun int(key: String): Int = string(key)?.toIntOrNull() ?: 0

    /** True when any debug argument was given: those runs stay out of the statistics. */
    val hasArguments: Boolean get() = BuildConfig.DEBUG && args.keys.any { it.startsWith("onb") || it == "demoProfile" || it == "appTab" }

    /** Fills a sample profile (a few lessons read, favorites, saved artworks) and skips the onboarding. */
    fun prepare(profile: Profile): Profile {
        if (!flag("demoProfile")) return profile
        var p = profile.copy(
            onboarded = true, firstName = "Max",
            opened = listOf("nuit", "joconde", "perle", "vague"),
            completedLessons = listOf("nuit", "joconde", "perle"),
            favorites = listOf("nuit", "baiser", "vague"),
            saved = listOf("joconde", "tournesols"),
        )
        if (flag("demoEmpty")) p = p.copy(opened = emptyList(), completedLessons = emptyList(), favorites = emptyList(), saved = emptyList())
        return p
    }
}
