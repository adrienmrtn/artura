package com.vikstudios.artura

import androidx.test.core.app.ApplicationProvider
import com.vikstudios.artura.app.AppGraph
import com.vikstudios.artura.core.ZoomTarget
import com.vikstudios.artura.core.ZoomViewer
import com.vikstudios.artura.data.Profile
import com.vikstudios.artura.feed.FeedEndCard
import com.vikstudios.artura.feed.FeedFilter
import com.vikstudios.artura.feed.FeedFilterSheet
import com.vikstudios.artura.feed.FeedSearchSheet
import com.vikstudios.artura.feed.HomeFeedView
import com.vikstudios.artura.feed.LibraryTab
import com.vikstudios.artura.feed.LibraryView
import com.vikstudios.artura.feed.SheetPanel
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.vikstudios.artura.app.CoverHost
import com.vikstudios.artura.app.CoverLayer
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalCoverHost
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.services.Analytics
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class FeedCaptures {
    @get:Rule val compose = createComposeRule()

    /**
     * Like `capture()`, but with the test clock driven by hand: the feed has endless animations
     * (slow zoom, swipe hint), so the screen never becomes idle on its own.
     */
    private fun capture(name: String, language: String = "en", content: @Composable () -> Unit) {
        Analytics.disabled = true
        AppLanguage.set(language)
        compose.mainClock.autoAdvance = false
        compose.setContent {
            val host = remember { CoverHost() }
            CompositionLocalProvider(
                LocalContent provides AppGraph.content, LocalUser provides AppGraph.user,
                LocalPro provides AppGraph.pro, LocalCoverHost provides host,
            ) {
                MaterialTheme(colorScheme = lightColorScheme(primary = Palette.blue, background = Palette.bg, surface = Palette.bg)) {
                    CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                        content()
                        CoverLayer(host)
                    }
                }
            }
        }
        compose.mainClock.advanceTimeBy(1500)
        compose.onRoot().captureRoboImage("../captures/$name.png")
    }

    /** Sample profile: a few lessons read, favorites, saved artworks (same as `-demoProfile`). */
    private fun demo(empty: Boolean = false) {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        AppGraph.user.profile = if (empty) Profile(onboarded = true) else Profile(
            onboarded = true, firstName = "Max",
            opened = listOf("nuit", "joconde", "perle", "vague"),
            completedLessons = listOf("nuit", "joconde", "perle"),
            favorites = listOf("nuit", "baiser", "vague"),
            saved = listOf("joconde", "tournesols"),
        )
    }

    @Test fun feed() { demo(); capture("feed_home") { HomeFeedView(onExplore = {}, onReview = {}) } }
    @Test fun feedFrench() { demo(); capture("feed_home_fr", "fr") { HomeFeedView(onExplore = {}, onReview = {}) } }
    @Test fun endCard() { demo(); capture("feed_end") { FeedEndCard(false, false, {}, {}, {}) } }
    @Test fun filter() {
        demo()
        capture("feed_filter") { SheetPanel({}) { FeedFilterSheet(FeedFilter(movementId = "impressionnisme", status = FeedFilter.Status.Unread)) {} } }
    }
    @Test fun search() { demo(); capture("feed_search") { SheetPanel({}) { FeedSearchSheet(onFilter = {}, autoFocus = false) } } }
    @Test fun library() { demo(); capture("feed_library") { SheetPanel({}) { LibraryView(LibraryTab.Favorites) } } }
    @Test fun libraryEmpty() { demo(empty = true); capture("feed_library_empty") { SheetPanel({}) { LibraryView(LibraryTab.Saved) } } }
    @Test fun zoom() { demo(); capture("feed_zoom") { ZoomViewer(ZoomTarget("hd_nuit", "art_nuit", "The Starry Night")) {} } }
}
