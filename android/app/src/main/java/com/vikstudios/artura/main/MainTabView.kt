package com.vikstudios.artura.main

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.IosShare
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.PillStyle
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.feed.HomeFeedView
import com.vikstudios.artura.feed.shareArtwork
import com.vikstudios.artura.learn.LessonPaywall
import com.vikstudios.artura.learn.LessonView
import com.vikstudios.artura.learn.QuizView
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.review.ReviewView
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.RatingPrompt

enum class AppTab {
    Today, Explore, Review, Games, Profile;

    val title: String
        get() = when (this) {
            Today -> L("Today")
            Explore -> L("Explore")
            Review -> L("Review")
            Games -> L("Games")
            Profile -> L("Profile")
        }

    val icon: ImageVector
        get() = when (this) {
            Today -> Icons.Rounded.Home
            Explore -> Icons.Rounded.GridView
            Review -> Icons.Rounded.Bookmark
            Games -> Icons.Rounded.Extension
            Profile -> Icons.Rounded.Person
        }

    companion object {
        /** Tab to open at launch, from the `appTab` debug argument. */
        val debugInitial: AppTab?
            get() = when (AppDebug.string("appTab")) {
                "explore" -> Explore
                "review" -> Review
                "games" -> Games
                "profile" -> Profile
                else -> null
            }
    }
}

@Composable
fun MainTabView() {
    val content = LocalContent.current
    var tab by rememberSaveable { mutableStateOf(AppTab.debugInitial ?: AppTab.Today) }

    LaunchedEffect(Unit) { content.activateCatalog() }

    Column(Modifier.fillMaxSize().background(Palette.bg)) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = { fadeIn(Anim.snappy()) togetherWith fadeOut(Anim.snappy()) },
            modifier = Modifier.weight(1f).fillMaxWidth(),
            label = "tabs",
        ) { current ->
            Box(Modifier.fillMaxSize()) {
                when (current) {
                    AppTab.Today -> HomeFeedView(onExplore = { tab = AppTab.Explore }, onReview = { tab = AppTab.Review })
                    AppTab.Explore -> ExploreView()
                    AppTab.Review -> ReviewView()
                    AppTab.Games -> GamesView()
                    AppTab.Profile -> ProfileView()
                }
            }
        }

        Column(Modifier.fillMaxWidth().background(Palette.bg)) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(if (Palette.isDark) hexColor(0x2E2B29) else hexColor(0xEFE9E5)))
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp).padding(top = 6.dp).navigationBarsPadding()) {
                AppTab.entries.forEach { item ->
                    val selected = tab == item
                    val scale by animateFloatAsState(if (selected) 1.06f else 1f, Anim.snappy(), label = "tab")
                    Column(
                        Modifier.weight(1f).height(52.dp).pressable(haptic = false) {
                            if (tab != item) {
                                Haptics.selection()
                                tab = item
                            }
                        },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
                    ) {
                        val color = if (selected) Palette.ink else if (Palette.isDark) hexColor(0x8F8882) else hexColor(0x6B6661)
                        Icon(item.icon, item.title, tint = color, modifier = Modifier.size(24.dp).graphicsLayer { scaleX = scale; scaleY = scale })
                        Text(item.title, style = figtree(11, FontWeight.Medium), color = color, maxLines = 1)
                    }
                }
            }
        }
    }
}

// MARK: - Lesson → quiz flow, presented full screen

/**
 * Opens a lesson full screen. Lessons of the online catalog are downloaded the first time they are opened.
 * Present it with `FullScreenCover(visible, onDismiss) { CourseFlow(artwork, onDismiss) }`.
 */
@Composable
fun CourseFlow(artwork: Artwork, onDismiss: () -> Unit) {
    val content = LocalContent.current
    var ready by remember { mutableStateOf(if (artwork.lesson.isEmpty()) null else artwork) }
    var failed by remember { mutableStateOf(false) }
    var attempt by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) { Haptics.press() }
    LaunchedEffect(attempt) {
        if (ready != null) return@LaunchedEffect
        failed = false
        val full = content.withLesson(artwork)
        ready = full
        failed = full == null
        if (full == null) Haptics.soft()
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        val r = ready
        if (r != null) {
            CourseContent(r, onDismiss)
        } else {
            Column(
                Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 24.dp).padding(top = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Row(Modifier.fillMaxWidth()) {
                    Box(
                        Modifier.size(44.dp).clip(CircleShape).background(Palette.card).pressable { onDismiss() },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.Close, L("Close"), tint = Palette.ink, modifier = Modifier.size(20.dp)) }
                }
                Spacer(Modifier.weight(1f))
                ArtImage(artwork.image, Modifier.size(180.dp, 220.dp).clip(RoundedCornerShape(16.dp)))
                Text(artwork.title, style = AType.heading, color = Palette.ink, textAlign = TextAlign.Center)
                if (failed) {
                    Text(L("This lesson could not be loaded. Check your connection and try again."),
                        style = AType.small, color = Palette.muted, textAlign = TextAlign.Center)
                    PillButton(L("Try again")) { Haptics.press(); attempt++ }
                } else {
                    CircularProgressIndicator(color = Palette.blue, strokeWidth = 3.dp, modifier = Modifier.size(28.dp))
                    Text(L("Preparing your lesson"), style = AType.small, color = Palette.muted)
                }
                Spacer(Modifier.weight(1f))
            }
        }
    }
}

/** Paywalls a free reader can meet inside a lesson. */
private enum class LessonWall {
    /** The quiz at the end of the lesson. */
    Quiz,
    /** A second lesson in the same day, cut after a few blocks. */
    Lesson,
}

@Composable
private fun CourseContent(artwork: Artwork, onDismiss: () -> Unit) {
    val user = LocalUser.current
    val pro = LocalPro.current
    var phase by rememberSaveable { mutableIntStateOf(0) }
    var score by rememberSaveable { mutableIntStateOf(0) }
    /** True if this lesson is the one a free reader can read in full today. */
    var freeToday by remember { mutableStateOf(true) }
    var wall by remember { mutableStateOf<LessonWall?>(null) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        user.markOpened(artwork.id)
        RatingPrompt.noteOpened(context, artwork.id)
        if (!pro.isPro) freeToday = user.claimFreeLesson(artwork.id)
    }

    AnimatedContent(
        targetState = phase,
        transitionSpec = {
            if (targetState > initialState) (slideInHorizontally(Anim.gentle()) { it } + fadeIn(Anim.gentle())) togetherWith
                (slideOutHorizontally(Anim.gentle()) { -it } + fadeOut(Anim.gentle()))
            else (slideInHorizontally(Anim.gentle()) { -it } + fadeIn(Anim.gentle())) togetherWith
                (slideOutHorizontally(Anim.gentle()) { it } + fadeOut(Anim.gentle()))
        },
        label = "course",
    ) { p ->
        when (p) {
            0 -> LessonView(
                artwork = artwork,
                freeTaps = if (pro.isPro || freeToday) null else 2,
                onBlocked = { wall = LessonWall.Lesson },
                onContinue = { taps ->
                    if (RatingPrompt.shouldAsk(context, artwork.id, taps)) {
                        // After the block has settled (and an interactive block has opened).
                        scope.launch {
                            delay(800)
                            Analytics.track("rating_prompt", mapOf("from" to "first_lesson", "artwork" to artwork.id))
                            RatingPrompt.request(context)
                        }
                    }
                },
                onBack = onDismiss,
                onFinish = {
                    if (pro.isPro) {
                        Haptics.soft()
                        phase = 1
                    } else {
                        // The lesson is read: it counts, quiz or not.
                        user.completeLesson(artwork.id)
                        wall = LessonWall.Quiz
                    }
                },
            )
            1 -> QuizView(artwork = artwork, onBack = { phase = 0 }) { result ->
                score = result
                Analytics.track("quiz_completed", mapOf("artwork" to artwork.id, "score" to result, "total" to artwork.quiz.size))
                user.completeLesson(artwork.id)
                phase = 2
            }
            else -> ResultView(
                title = if (score == artwork.quiz.size) L("Perfect score!") else L("Lesson complete"),
                detail = L("%@ of %@ correct", "$score", "${artwork.quiz.size}"),
                celebrate = score == artwork.quiz.size,
                shareArtwork = artwork,
                onDone = onDismiss,
            )
        }
    }

    FullScreenCover(visible = wall == LessonWall.Quiz, onDismiss = { wall = null }) {
        LessonPaywall(
            artwork = artwork,
            title = L("The quiz is part of Artura Pro"),
            subtitle = L("Test what you just read about %@, and remember it for good.", artwork.title),
            closeTitle = L("Not now"),
            onClose = { wall = null },
            onUnlocked = { wall = null; phase = 1 },
        )
    }
    // No way to go on reading without subscribing: the only way out leaves the lesson.
    FullScreenCover(visible = wall == LessonWall.Lesson, onDismiss = {}, dismissable = false) {
        LessonPaywall(
            artwork = artwork,
            title = L("Continue this lesson"),
            subtitle = L("Read the rest of %@, and every other lesson, with Artura Pro.", artwork.title),
            closeTitle = L("Leave this lesson"),
            closeDelay = 3,
            onClose = { wall = null; onDismiss() },
            onUnlocked = { wall = null },
        )
    }
}

/** End screen, shared by the quiz and the games. */
@Composable
fun ResultView(
    title: String,
    detail: String,
    celebrate: Boolean = true,
    /** Artwork to offer for sharing (end of a lesson). */
    shareArtwork: Artwork? = null,
    onReplay: (() -> Unit)? = null,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    var pop by remember { mutableStateOf(false) }
    val p by animateFloatAsState(if (pop) 1f else 0f, Anim.bouncy(), label = "pop")
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        pop = true
        if (celebrate) Haptics.success() else Haptics.soft()
    }
    Column(
        Modifier.fillMaxSize().background(Palette.bg).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = 24.dp).padding(bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.weight(1f))
        Box(
            Modifier.size(132.dp).graphicsLayer { val s = 0.8f + 0.2f * p; scaleX = s; scaleY = s; alpha = p }
                .clip(CircleShape).background(if (celebrate) Palette.mist else Palette.green),
            contentAlignment = Alignment.Center,
        ) {
            Icon(if (celebrate) Icons.Rounded.Star else Icons.Rounded.Check, null,
                tint = if (celebrate) Palette.yellow else Color.White, modifier = Modifier.size(64.dp))
        }
        Text(title, style = figtree(32, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center, modifier = Modifier.appearUp(0.2))
        Text(detail, style = AType.body, color = Palette.muted, textAlign = TextAlign.Center, modifier = Modifier.appearUp(0.3))
        Spacer(Modifier.weight(1f))
        if (onReplay != null) PillButton(L("Play again"), style = PillStyle.Secondary, onClick = onReplay)
        if (shareArtwork != null) {
            PillButton(style = PillStyle.Secondary, onClick = { shareArtwork(context, shareArtwork) }) {
                Icon(Icons.Rounded.IosShare, null, tint = Palette.ink, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(8.dp))
                Text(L("Share this artwork"), style = AType.bodyStrong, color = Palette.ink)
            }
        }
        PillButton(L("Done"), onClick = onDone)
    }
}
