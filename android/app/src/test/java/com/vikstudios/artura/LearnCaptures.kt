package com.vikstudios.artura

import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.vikstudios.artura.app.AppGraph
import com.vikstudios.artura.app.CoverHost
import com.vikstudios.artura.app.CoverLayer
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalCoverHost
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.learn.LessonView
import com.vikstudios.artura.learn.PaintingStudio
import com.vikstudios.artura.learn.QuizView
import com.vikstudios.artura.review.ReviewDeck
import com.vikstudios.artura.review.ReviewSessionView
import com.vikstudios.artura.review.ReviewView
import com.vikstudios.artura.services.Analytics
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Captures of the lesson, the painting studio, the quiz and the Review tab (android/captures/learn_*.png). */
@RunWith(RobolectricTestRunner::class)
class LearnCaptures {
    @get:Rule val rule = createComposeRule()

    private fun art(id: String): Artwork {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        Analytics.disabled = true
        return AppGraph.content.artwork(id)!!
    }

    private fun show(content: @Composable () -> Unit) {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        Analytics.disabled = true
        rule.mainClock.autoAdvance = false
        rule.setContent {
            val host = remember { CoverHost() }
            CompositionLocalProvider(
                LocalContent provides AppGraph.content,
                LocalUser provides AppGraph.user,
                LocalPro provides AppGraph.pro,
                LocalCoverHost provides host,
            ) {
                MaterialTheme(colorScheme = captureColorScheme()) {
                    CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                        content()
                        CoverLayer(host)
                    }
                }
            }
        }
        pause(1500)
    }

    private fun pause(ms: Long) = rule.mainClock.advanceTimeBy(ms)
    private fun shot(name: String) = rule.onRoot().captureRoboImage("../captures/learn_$name$captureSuffix.png")

    private fun studio(id: String, type: String, ready: () -> Unit = {}) {
        val a = art(id)
        show { PaintingStudio(a, a.lesson.first { it.type == type }) {} }
        ready()
    }

    @Test fun lessonStart() {
        val a = art("nuit")
        show { LessonView(a, onBack = {}, onFinish = {}) }
        shot("lesson_start")
    }

    @Test fun lessonBlocks() {
        val a = art("nuit").let { it.copy(lesson = it.lesson.filter { b -> !b.isInteractive }) }
        show { LessonView(a, onBack = {}, onFinish = {}) }
        repeat(4) { rule.onNodeWithText("Continue").performClick(); pause(600) }
        shot("lesson_blocks")
    }

    @Test fun lessonCard() {
        val a = art("nuit").let { it.copy(lesson = it.lesson.take(4)) }
        show { LessonView(a, onBack = {}, onFinish = {}) }
        repeat(4) { rule.onNodeWithText("Continue").performClick(); pause(600) }
        pause(2000)
        shot("lesson_studio_open")
    }

    @Test fun lessonOnboarding() {
        val a = art("nuit")
        show { LessonView(a, onBack = {}, onFinish = {}, pill = "Your first guided tour", blocks = a.previewLesson, finishTitle = "Finish the tour", onSkip = {}) }
        shot("lesson_onboarding")
    }

    @Test fun studioTour() = studio("nuit", "tour") {
        rule.onNodeWithText("Tap to continue").performClick()
        pause(2500)
        shot("studio_tour")
    }

    @Test fun studioFindStart() = studio("joconde", "find") { shot("studio_find") }

    @Test fun studioLines() = studio("nuit", "lines") {
        rule.onNodeWithText("Tap to continue").performClick(); pause(1500)
        rule.onNodeWithText("Tap to continue").performClick(); pause(1500)
        shot("studio_lines")
    }

    @Test fun studioPalette() {
        val a = art("nuit")
        val block = a.lesson.first { it.type == "palette" }
        show { PaintingStudio(a, block) {} }
        rule.onNodeWithContentDescription(block.swatches!!.first().name).performClick()
        pause(1000)
        shot("studio_palette")
    }

    @Test fun studioExplore() = studio("perle", "explore") { shot("studio_explore") }

    @Test fun quiz() {
        val a = art("nuit")
        show { QuizView(a, onBack = {}, onFinish = {}) }
        shot("quiz")
        val q = a.quiz.first()
        val wrong = q.options.indices.first { it != q.answer }
        rule.onNodeWithText(q.options[wrong]).performClick()
        pause(1000)
        shot("quiz_answered")
    }

    private fun demoProfile() {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        AppGraph.user.update {
            it.copy(onboarded = true, completedLessons = listOf("nuit", "joconde", "perle"), opened = listOf("nuit", "joconde", "perle", "vague"),
                favorites = listOf("nuit", "baiser", "vague"), saved = listOf("joconde", "tournesols"))
        }
    }

    @Test fun reviewTab() {
        demoProfile()
        show { ReviewView() }
        shot("review")
    }

    @Test fun reviewPractice() {
        demoProfile()
        show { ReviewView() }
        rule.onNodeWithText("Practice").performClick()
        pause(800)
        shot("review_practice")
    }

    @Test fun reviewEmpty() {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        AppGraph.user.update { it.copy(completedLessons = emptyList(), opened = emptyList(), favorites = emptyList(), saved = emptyList()) }
        show { ReviewView() }
        shot("review_empty")
    }

    @Test fun reviewSession() {
        demoProfile()
        val c = AppGraph.content
        val deck = ReviewDeck.daily(listOf(c.artwork("nuit")!!, c.artwork("perle")!!), c.artworks)
        show { ReviewSessionView(deck) {} }
        shot("session")
        rule.onNodeWithText(deck.cards.first().choices.first().title).performClick()
        pause(800)
        shot("session_answered")
    }
}
