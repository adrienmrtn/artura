package com.vikstudios.artura.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.ProgressTrack
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Profile
import com.vikstudios.artura.learn.LessonView
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.TrialOffer
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The onboarding steps, in order. Names match the iOS cases (also used by the `onbStep` debug argument). */
@Suppress("EnumEntryName")
enum class OnbStep {
    welcome, language, hello, daily, pocketMuseum, photo, quotes,
    questionsIntro, nameStep, gender, motivation, arts, recognize, knowledge, museum,
    testIntro, flashTest, flashResult,
    study, learnToLook, abilities, chooseCourse, lesson, afterLesson,
    phoneTime, phoneResult, attention, projection, graph,
    streak, reminder, widget, madeBy, loading, plan, socialProof, account,
    gift, trialNotif, trialTimeline, trial;

    val showsBar: Boolean
        get() = when (this) {
            welcome, quotes, lesson, loading, account, gift, trialNotif, trialTimeline, trial -> false
            else -> true
        }

    val progress: Double get() = minOf(1.0, ordinal.toDouble() / account.ordinal.toDouble())

    val previous: OnbStep?
        get() = when (this) {
            welcome, gift, trialNotif, trialTimeline, trial -> null
            plan -> madeBy
            else -> entries[ordinal - 1]
        }

    /** Name of the step, as on iOS ("name" is reserved in Kotlin enums). */
    val id: String get() = if (this == nameStep) "name" else name

    /** Screens that draw under the status bar themselves (edge-to-edge image, dark background). */
    val edgeToEdge: Boolean get() = this == welcome || this == quotes
}

/**
 * Where the onboarding is. Kept outside the composition: changing the language (language screens) rebuilds the
 * whole interface in the new language, and the onboarding must stay on the same screen.
 */
private object OnbState {
    var step by mutableStateOf(OnboardingDebug.startStep ?: OnbStep.welcome)
    var forward by mutableStateOf(true)
    var moving = false
    var loginShortcut = false
    var trialReminder by mutableStateOf(false)
}

@Composable
fun OnboardingFlow() {
    val user = LocalUser.current
    val content = LocalContent.current
    val pro = LocalPro.current
    val scope = rememberCoroutineScope()
    val s = OnbState
    val step = s.step

    val course = content.artwork(user.profile.firstCourse) ?: content.artwork("nuit") ?: content.artworks.firstOrNull()
    val offer: TrialOffer? = TrialOffer.of(pro.yearly) ?: TrialOffer.preview(3)
    val extendedOffer: TrialOffer? = TrialOffer.of(pro.yearlyExtended) ?: TrialOffer.preview(7, gift = true)

    fun move(target: OnbStep) {
        Analytics.track("onboarding_step", mapOf(
            "from" to s.step.id, "to" to target.id, "forward" to (target.ordinal > s.step.ordinal),
            "answers" to user.profile.onboardingAnswers,
        ))
        s.step = target
        scope.launch { delay(300); Haptics.soft() }
        scope.launch { delay(400); s.moving = false }
    }

    fun go(target: OnbStep) {
        if (s.moving || target == s.step) return
        s.moving = true
        s.forward = target.ordinal > s.step.ordinal
        move(target)
    }

    fun finish() {
        Haptics.success()
        Analytics.track("onboarding_completed", mapOf(
            "last_step" to s.step.id, "is_pro" to pro.isPro, "answers" to user.profile.onboardingAnswers,
        ))
        user.update { it.copy(onboarded = true) }
    }

    fun next() {
        val target = OnbStep.entries.getOrNull(s.step.ordinal + 1)
        if (s.step == OnbStep.account && (offer == null || pro.isPro)) finish()
        else if (target != null) go(target)
        else finish()
    }

    fun back() {
        val target = s.step.previous ?: return
        Haptics.tap()
        if (s.step == OnbStep.account && s.loginShortcut) {
            s.loginShortcut = false
            go(OnbStep.welcome)
        } else {
            go(target)
        }
    }

    // Once the onboarding is over, the next one (after a reset) starts again from the beginning.
    DisposableEffect(Unit) {
        onDispose {
            if (user.profile.onboarded) {
                s.step = OnbStep.welcome
                s.forward = true
                s.moving = false
                s.loginShortcut = false
                s.trialReminder = false
            }
        }
    }

    val density = LocalDensity.current
    Column(Modifier.fillMaxSize().background(Palette.bg).imePadding()) {
        AnimatedVisibility(step.showsBar, enter = fadeIn(), exit = fadeOut()) {
            Row(
                Modifier.statusBarsPadding().fillMaxWidth().height(44.dp + 8.dp).padding(horizontal = 24.dp).padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.offset(x = (-12).dp).size(44.dp).pressable { back() }, contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, L("Back"), tint = Palette.ink, modifier = Modifier.size(32.dp))
                }
                ProgressTrack(step.progress, Modifier.weight(1f).offset(x = (-12).dp))
            }
        }
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                val side = if (s.forward) 1 else -1
                val inX = with(density) { (48 * side).dp.roundToPx() }
                val outX = with(density) { (-32 * side).dp.roundToPx() }
                (slideInHorizontally(tween(550, delayMillis = 100, easing = Anim.glideEasing)) { inX } +
                    fadeIn(tween(550, delayMillis = 100, easing = Anim.glideEasing))) togetherWith
                    (slideOutHorizontally(tween(180)) { outX } + fadeOut(tween(180)))
            },
            modifier = Modifier.weight(1f).fillMaxWidth(),
            label = "onboarding",
        ) { current ->
            val inset = when {
                current.edgeToEdge -> Modifier
                current.showsBar -> Modifier.navigationBarsPadding()
                else -> Modifier.statusBarsPadding().navigationBarsPadding()
            }
            Box(Modifier.fillMaxSize().then(inset)) {
                Screen(current, course, offer, extendedOffer, ::next, ::back, ::go, ::finish)
            }
        }
    }
}

@Composable
private fun Screen(
    step: OnbStep,
    course: com.vikstudios.artura.data.Artwork?,
    offer: TrialOffer?,
    extendedOffer: TrialOffer?,
    next: () -> Unit,
    back: () -> Unit,
    go: (OnbStep) -> Unit,
    finish: () -> Unit,
) {
    val user = LocalUser.current
    when (step) {
        OnbStep.welcome -> WelcomeScreen(onNext = next, onLogin = {
            OnbState.loginShortcut = true
            go(OnbStep.account)
        })
        OnbStep.language -> LanguageScreen(next)
        OnbStep.hello -> HelloScreen(next)
        OnbStep.daily -> DailyScreen(next)
        OnbStep.pocketMuseum -> PocketMuseumScreen(next)
        OnbStep.photo -> PhotoScreen(next)
        OnbStep.quotes -> QuotesScreen(onBack = back, onNext = next)
        OnbStep.questionsIntro -> QuestionsIntroScreen(next)
        OnbStep.nameStep -> NameScreen(next)
        OnbStep.gender -> GenderScreen(next)
        OnbStep.motivation -> MotivationScreen(next)
        OnbStep.arts -> ArtsScreen(next)
        OnbStep.recognize -> RecognizeScreen(next)
        OnbStep.knowledge -> KnowledgeScreen(next)
        OnbStep.museum -> MuseumScreen(next)
        OnbStep.testIntro -> TestIntroScreen(next)
        OnbStep.flashTest -> FlashTestScreen(next)
        OnbStep.flashResult -> FlashResultScreen(next)
        OnbStep.study -> StudyScreen(next)
        OnbStep.learnToLook -> LearnToLookScreen(next)
        OnbStep.abilities -> AbilitiesScreen(next)
        OnbStep.chooseCourse -> ChooseCourseScreen(next)
        OnbStep.lesson -> if (course != null) {
            LessonView(
                artwork = course,
                pill = L("Your first guided tour"),
                blocks = course.previewLesson,
                finishTitle = L("Finish the tour"),
                onSkip = next,
                onBack = back,
                onFinish = {
                    user.update { it.copy(firstCourse = course.id) }
                    user.markOpened(course.id)
                    user.markPlayedToday()
                    next()
                },
            )
        }
        OnbStep.afterLesson -> AfterLessonScreen(next)
        OnbStep.phoneTime -> PhoneTimeScreen(next)
        OnbStep.phoneResult -> PhoneResultScreen(next)
        OnbStep.attention -> AttentionScreen(next)
        OnbStep.projection -> ProjectionScreen(next)
        OnbStep.graph -> GraphScreen(next)
        OnbStep.streak -> StreakScreen(next)
        OnbStep.reminder -> ReminderScreen(onNext = next)
        OnbStep.widget -> WidgetScreen(onNext = next)
        OnbStep.madeBy -> MadeByScreen(next)
        OnbStep.loading -> LoadingScreen(onNext = next)
        OnbStep.plan -> PlanScreen(onNext = next)
        OnbStep.socialProof -> SocialProofScreen(onNext = next)
        OnbStep.account -> AccountScreen(onBack = back, onNext = next)
        OnbStep.gift -> if (offer != null) GiftScreen(offer = offer, onNext = next)
        OnbStep.trialNotif -> if (offer != null) TrialNotifScreen(
            offer = offer, reminder = OnbState.trialReminder, onReminderChange = { OnbState.trialReminder = it }, onNext = next)
        OnbStep.trialTimeline -> if (offer != null) TrialTimelineScreen(offer = offer, onNext = next)
        OnbStep.trial -> if (offer != null) TrialScreen(
            offer = offer, extendedOffer = extendedOffer, reminder = OnbState.trialReminder, onFinish = finish)
    }
}

/** Debug launch arguments of the onboarding (debug builds only), same names as on iOS. */
object OnboardingDebug {
    /** True in a debug build. */
    val isDebug: Boolean get() = AppDebug.isDebug

    val startStep: OnbStep?
        get() {
            val name = AppDebug.string("onbStep") ?: return null
            return OnbStep.entries.firstOrNull { it.id == name }
        }

    /** Sample offer, to view the trial screens without a loaded Play product. */
    fun previewOffer(days: Int): TrialOffer? = if (flag("onbPreviewOffer")) TrialOffer.preview(days) else null

    /** True if the launch argument `<key> YES` is present (always false outside debug). */
    fun flag(key: String) = AppDebug.flag(key)

    /** Integer passed as a launch argument, 0 by default and outside debug. */
    fun int(key: String) = AppDebug.int(key)

    fun string(key: String) = AppDebug.string(key)

    /** Prepares a sample profile when a screen is opened directly. */
    fun prepare(profile: Profile): Profile {
        if (!AppDebug.isDebug) return profile
        if (flag("skipOnboarding")) return profile.copy(onboarded = true)
        if (AppDebug.string("onbStep") == null) return profile
        var p = profile.copy(onboarded = false)
        AppDebug.string("onbName")?.let { p = p.copy(firstName = it) }
        if (p.flashKnown.isEmpty()) p = p.copy(flashKnown = FlashCard.all.take(4).map { it.id })
        return p
    }
}
