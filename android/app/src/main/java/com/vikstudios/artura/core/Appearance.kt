package com.vikstudios.artura.core

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Appearance chosen in the profile: light (the default), dark, or the phone's setting. Same as iOS. */
enum class Appearance(val key: String) {
    Light("light"), Dark("dark"), System("system");

    val title: String
        get() = when (this) {
            Light -> L("Light")
            Dark -> L("Dark")
            System -> L("Same as phone")
        }

    companion object {
        private const val prefsKey = "artura.appearance"
        private lateinit var app: Context

        /** The chosen appearance. Observable: the app redraws when it changes. */
        var current by mutableStateOf(Light)
            private set

        fun init(context: Context) {
            app = context.applicationContext
            val saved = app.getSharedPreferences("artura", Context.MODE_PRIVATE).getString(prefsKey, null)
            current = entries.firstOrNull { it.key == saved } ?: Light
        }

        fun set(value: Appearance) {
            current = value
            if (::app.isInitialized) {
                app.getSharedPreferences("artura", Context.MODE_PRIVATE).edit().putString(prefsKey, value.key).apply()
            }
        }
    }
}
