package com.vikstudios.artura

import androidx.test.core.app.ApplicationProvider
import com.vikstudios.artura.app.AppGraph
import com.vikstudios.artura.data.UserStore
import com.vikstudios.artura.games.GameHost
import com.vikstudios.artura.games.GameKind
import com.vikstudios.artura.main.ExploreView
import com.vikstudios.artura.main.GamesView
import com.vikstudios.artura.main.MovementDetailView
import com.vikstudios.artura.main.ProfileView
import com.vikstudios.artura.main.SignInSheet
import com.vikstudios.artura.widget.DailyCatalog
import com.vikstudios.artura.widget.DailyWidgetStyle
import com.vikstudios.artura.widget.WidgetGuideView
import com.vikstudios.artura.widget.WidgetPreview
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.LayoutDirection
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
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.LocalDate

/** Explore, Games, Profile tabs, the games and the widget. Images in android/captures/main_*.png. */
@RunWith(RobolectricTestRunner::class)
class MainCaptures {
    @get:Rule val rule = createComposeRule()

    /**
     * Like `capture()`, but with the test clock under control: screens with endless animations (sky
     * header, floating Mona Lisa, game timers) never become idle, which blocks the activity capture.
     */
    private fun capture(name: String, language: String = "en", content: @Composable () -> Unit) {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        AppGraph.init(context)
        Analytics.disabled = true
        AppLanguage.set(language)
        rule.mainClock.autoAdvance = false
        rule.setContent {
            val host = remember { CoverHost() }
            CompositionLocalProvider(
                LocalContent provides AppGraph.content,
                LocalUser provides AppGraph.user,
                LocalPro provides AppGraph.pro,
                LocalCoverHost provides host,
                LocalLayoutDirection provides if (AppLanguage.isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr,
            ) {
                MaterialTheme(colorScheme = lightColorScheme(primary = Palette.blue, background = Palette.bg, surface = Palette.bg)) {
                    CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                        Box(Modifier.fillMaxSize().background(Palette.bg)) {
                            content()
                            CoverLayer(host)
                        }
                    }
                }
            }
        }
        rule.mainClock.advanceTimeBy(2500)
        rule.onRoot().captureRoboImage("../captures/$name.png")
    }

    @Before
    fun demoProfile() {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        val today = LocalDate.now()
        AppGraph.user.update {
            it.copy(
                onboarded = true, firstName = "Max", level = "Enthusiast", avatar = 2,
                opened = listOf("nuit", "joconde", "perle", "vague"),
                completedLessons = listOf("nuit", "joconde", "perle"),
                favorites = listOf("nuit", "baiser", "vague"),
                saved = listOf("joconde", "tournesols"),
                playedDays = listOf(UserStore.dayKey(today), UserStore.dayKey(today.minusDays(1))),
                gamesWon = 4,
                trainingDay = UserStore.dayKey(today), trainingCount = 12,
            )
        }
    }

    @Test fun explore() = capture("main_explore") { ExploreView() }
    @Test fun movement() = capture("main_movement") {
        MovementDetailView(AppGraph.content.movements.first()) {}
    }
    @Test fun games() = capture("main_games") { GamesView() }
    @Test fun profile() = capture("main_profile") { ProfileView() }
    @Test fun signIn() = capture("main_signin") { SignInSheet {} }
    @Test fun zoom() = capture("main_game_zoom") { GameHost(GameKind.Zoom) {} }
    @Test fun chronology() = capture("main_game_chronology") { GameHost(GameKind.Chronology) {} }
    @Test fun palette() = capture("main_game_palette") { GameHost(GameKind.Palette) {} }
    @Test fun trueFalse() = capture("main_game_truefalse") { GameHost(GameKind.TrueFalse) {} }
    @Test fun training() = capture("main_game_training") { GameHost(GameKind.Training) {} }
    @Test fun widgetGuide() = capture("main_widget_guide") { WidgetGuideView {} }
    @Test fun widgetGuideFr() = capture("main_widget_guide_fr", language = "fr") { WidgetGuideView {} }
    @Test fun widgets() = capture("main_widgets") {
        val art = DailyCatalog.artwork(ApplicationProvider.getApplicationContext())
        Column(Modifier.padding(24.dp)) {
            WidgetPreview(art, DailyWidgetStyle.Small, Modifier.size(150.dp))
            WidgetPreview(art, DailyWidgetStyle.Medium, Modifier.padding(top = 16.dp).fillMaxWidth().height(150.dp))
            WidgetPreview(art, DailyWidgetStyle.Large, Modifier.padding(top = 16.dp).fillMaxWidth().height(330.dp))
        }
    }
}
