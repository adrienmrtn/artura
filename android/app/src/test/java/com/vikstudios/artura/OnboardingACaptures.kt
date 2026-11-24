package com.vikstudios.artura

import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
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
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.data.Profile
import com.vikstudios.artura.onboarding.AbilitiesScreen
import com.vikstudios.artura.onboarding.ArtsScreen
import com.vikstudios.artura.onboarding.ChooseCourseScreen
import com.vikstudios.artura.onboarding.DailyScreen
import com.vikstudios.artura.onboarding.FlashResultScreen
import com.vikstudios.artura.onboarding.FlashTestScreen
import com.vikstudios.artura.onboarding.GenderScreen
import com.vikstudios.artura.onboarding.GraphScreen
import com.vikstudios.artura.onboarding.HelloScreen
import com.vikstudios.artura.onboarding.KnowledgeScreen
import com.vikstudios.artura.onboarding.LanguageScreen
import com.vikstudios.artura.onboarding.MotivationScreen
import com.vikstudios.artura.onboarding.NameScreen
import com.vikstudios.artura.onboarding.OnboardingFlow
import com.vikstudios.artura.onboarding.PhoneResultScreen
import com.vikstudios.artura.onboarding.PhoneTimeScreen
import com.vikstudios.artura.onboarding.PhotoScreen
import com.vikstudios.artura.onboarding.ProjectionScreen
import com.vikstudios.artura.onboarding.QuotesScreen
import com.vikstudios.artura.onboarding.StreakScreen
import com.vikstudios.artura.onboarding.StudyScreen
import com.vikstudios.artura.onboarding.WelcomeScreen
import com.vikstudios.artura.services.Analytics
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Onboarding screens (part A), rendered after `millis` of animation. */
@RunWith(RobolectricTestRunner::class)
class OnboardingACaptures {
    @get:Rule val rule = createComposeRule()

    private fun shot(name: String, millis: Long = 4000, profile: (Profile) -> Profile = { it }, content: @Composable () -> Unit) {
        AppGraph.init(ApplicationProvider.getApplicationContext())
        Analytics.disabled = true
        AppLanguage.set("en")
        AppGraph.user.profile = profile(Profile(firstName = "Max", flashKnown = listOf("joconde", "nuit", "glaneuses", "menines")))
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
        rule.mainClock.advanceTimeBy(millis)
        rule.onRoot().captureRoboImage("../captures/$name$captureSuffix.png")
    }

    @Test fun flow() = shot("onbA_flow_welcome") { OnboardingFlow() }
    @Test fun welcome() = shot("onbA_welcome") { WelcomeScreen(onNext = {}, onLogin = {}) }
    @Test fun language() = shot("onbA_language") { LanguageScreen {} }
    @Test fun hello() = shot("onbA_hello", 9000) { HelloScreen {} }
    @Test fun daily() = shot("onbA_daily") { DailyScreen {} }
    @Test fun photo() = shot("onbA_photo") { PhotoScreen {} }
    @Test fun quotes() = shot("onbA_quotes") { QuotesScreen(onBack = {}, onNext = {}) }
    @Test fun name() = shot("onbA_name") { NameScreen {} }
    @Test fun gender() = shot("onbA_gender", profile = { it.copy(gender = "femme") }) { GenderScreen {} }
    @Test fun motivation() = shot("onbA_motivation", profile = { it.copy(goals = listOf("Just for fun")) }) { MotivationScreen {} }
    @Test fun arts() = shot("onbA_arts") { ArtsScreen {} }
    @Test fun knowledge() = shot("onbA_knowledge", profile = { it.copy(level = "Enthusiast") }) { KnowledgeScreen {} }
    @Test fun flashTest() = shot("onbA_flashtest") { FlashTestScreen {} }
    @Test fun flashResult() = shot("onbA_flashresult", 5000) { FlashResultScreen {} }
    @Test fun study() = shot("onbA_study") { StudyScreen {} }
    @Test fun abilities() = shot("onbA_abilities") { AbilitiesScreen {} }
    @Test fun chooseCourse() = shot("onbA_choosecourse", profile = { it.copy(firstCourse = "nuit") }) { ChooseCourseScreen {} }
    @Test fun phoneTime() = shot("onbA_phonetime") { PhoneTimeScreen {} }
    @Test fun phoneResult() = shot("onbA_phoneresult", 6000) { PhoneResultScreen {} }
    @Test fun projection() = shot("onbA_projection", 5000) { ProjectionScreen {} }
    @Test fun graph() = shot("onbA_graph", 6000) { GraphScreen {} }
    @Test fun streak() = shot("onbA_streak", 3000) { StreakScreen {} }
}
