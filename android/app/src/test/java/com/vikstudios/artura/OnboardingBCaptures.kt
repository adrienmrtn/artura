package com.vikstudios.artura

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.vikstudios.artura.app.AppGraph
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.learn.LessonPaywall
import com.vikstudios.artura.onboarding.AccountScreen
import com.vikstudios.artura.onboarding.ExitOfferSheet
import com.vikstudios.artura.onboarding.GiftBox
import com.vikstudios.artura.onboarding.GiftScreen
import com.vikstudios.artura.onboarding.LoadingScreen
import com.vikstudios.artura.onboarding.MadeByScreen
import com.vikstudios.artura.onboarding.PaywallScreen
import com.vikstudios.artura.onboarding.PlanScreen
import com.vikstudios.artura.onboarding.ReminderScreen
import com.vikstudios.artura.onboarding.SocialProofScreen
import com.vikstudios.artura.onboarding.TrialClock
import com.vikstudios.artura.onboarding.TrialNotifScreen
import com.vikstudios.artura.onboarding.TrialScreen
import com.vikstudios.artura.onboarding.TrialTimelineScreen
import com.vikstudios.artura.onboarding.WidgetScreen
import com.vikstudios.artura.services.TrialOffer
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.LayoutDirection
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.vikstudios.artura.app.CoverHost
import com.vikstudios.artura.app.CoverLayer
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalCoverHost
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.services.Analytics
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Onboarding part B (setup and paywall screens) and the lesson paywall. */
@RunWith(RobolectricTestRunner::class)
class OnboardingBCaptures {
    @get:Rule val rule = createComposeRule()

    /**
     * Like `capture()`, with a manual clock: these screens run endless animations (floating paintings,
     * rays), which never let the automatic clock settle. The screen is shown `ms` milliseconds in.
     */
    private fun capture(name: String, language: String = "en", ms: Long = 9000, content: @Composable () -> Unit) {
        AppGraph.init(ApplicationProvider.getApplicationContext())
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
                MaterialTheme(colorScheme = captureColorScheme()) {
                    CompositionLocalProvider(LocalTextStyle provides AType.body.copy(color = Palette.ink)) {
                        content()
                        CoverLayer(host)
                    }
                }
            }
        }
        var t = 0L
        while (t < ms) { rule.mainClock.advanceTimeBy(100); t += 100 }
        rule.onRoot().captureRoboImage("../captures/$name$captureSuffix.png")
    }

    @Test fun reminder() = capture("onb_reminder") { ReminderScreen {} }
    @Test fun widget() = capture("onb_widget") { WidgetScreen {} }
    @Test fun madeBy() = capture("onb_made_by") { MadeByScreen {} }
    @Test fun loading() = capture("onb_loading") { LoadingScreen {} }
    @Test fun plan() = capture("onb_plan") { PlanScreen {} }
    @Test fun socialProof() = capture("onb_social_proof") { SocialProofScreen {} }
    @Test fun account() = capture("onb_account") { AccountScreen({}, {}) }
    @Test fun gift() = capture("onb_gift") { GiftScreen(TrialOffer.preview(3)) {} }
    @Test fun giftBoxes() = capture("onb_giftbox") {
        Box(Modifier.fillMaxSize().background(Palette.bg)) {
            Box(Modifier.align(Alignment.TopCenter)) { GiftBox(false) }
            Box(Modifier.align(Alignment.Center)) { GiftBox(true) }
            Box(Modifier.align(Alignment.BottomCenter)) { TrialClock(3) }
        }
    }
    @Test fun trialNotif() = capture("onb_trial_notif") { TrialNotifScreen(TrialOffer.preview(3), false, {}) {} }
    @Test fun trialTimeline() = capture("onb_trial_timeline") { TrialTimelineScreen(TrialOffer.preview(3)) {} }
    @Test fun trial() = capture("onb_trial") { TrialScreen(TrialOffer.preview(3), TrialOffer.preview(7, true), false) {} }
    @Test fun exitOffer() = capture("onb_exit_offer") {
        ExitOfferSheet(AppGraph.pro, TrialOffer.preview(7, true), 3, "$29.99", 40, "Max", {}, {})
    }
    @Test fun paywall() = capture("paywall_plans") { PaywallScreen {} }
    @Test fun lessonPaywall() = capture("paywall_lesson") {
        LessonPaywall(AppGraph.content.artwork("nuit")!!, "The quiz is part of Artura Pro",
            "Test what you just read about The Starry Night, and remember it for good.", "Not now", 0, {}, {})
    }
    @Test fun trialFrench() = capture("onb_trial_fr", "fr") { TrialScreen(TrialOffer.preview(3), TrialOffer.preview(7, true), false) {} }
}
