package com.vikstudios.artura.services

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import com.google.android.play.core.review.ReviewManagerFactory

/**
 * Google Play rating prompt during the first lesson opened in the app, at the 5th tap on "Continue".
 * Asked once ever. The onboarding's guided tour is not concerned (it asks on its own screen).
 */
object RatingPrompt {
    /** Number of "Continue" taps after which the prompt is asked. */
    const val LESSON_TAP = 5
    private const val PREFS = "rating_prompt"
    private const val FIRST = "first_lesson"
    private const val ASKED = "lesson_asked"

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Remembers the first artwork whose lesson is opened in the app. */
    fun noteOpened(context: Context, id: String) {
        val p = prefs(context)
        if (p.getString(FIRST, null) == null) p.edit().putString(FIRST, id).apply()
    }

    /** True once: at the 5th "Continue" of the first lesson opened. Marks the prompt as asked. */
    fun shouldAsk(context: Context, id: String, taps: Int): Boolean {
        val p = prefs(context)
        if (taps != LESSON_TAP || p.getBoolean(ASKED, false) || p.getString(FIRST, null) != id) return false
        p.edit().putBoolean(ASKED, true).apply()
        return true
    }

    /** Shows the Play in-app review (Google decides whether it actually appears). Never throws. */
    fun request(context: Context) {
        var c = context
        while (c !is Activity && c is ContextWrapper) c = c.baseContext
        val activity = c as? Activity ?: return
        runCatching {
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (request.isSuccessful && !activity.isFinishing) manager.launchReviewFlow(activity, request.result)
            }
        }
    }
}
