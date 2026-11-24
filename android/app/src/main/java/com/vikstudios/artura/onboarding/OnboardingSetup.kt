package com.vikstudios.artura.onboarding

import android.Manifest
import android.app.Activity
import android.content.ContextWrapper
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArcHeaderShape
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.TextLinkButton
import com.vikstudios.artura.core.drawableId
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.avatarImages
import com.vikstudios.artura.data.avatarLabels
import com.vikstudios.artura.data.formatMinutes
import com.vikstudios.artura.services.GoogleAuth
import com.vikstudios.artura.services.Reminder
import com.vikstudios.artura.services.Analytics
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

// Port of OnboardingSetup.swift: reminder, widget, loading, program, social proof, account, sign-in.

// MARK: Reminder (slider and sun)

/** Small landscape where the sun follows the chosen time. `minutes` since midnight (360 = 6 AM, 1380 = 11 PM). */
@Composable
fun SunScene(minutes: Double, modifier: Modifier = Modifier) {
    val isNight = minutes >= 1230
    val progress = ((minutes - 360) / (1230 - 360)).coerceIn(0.0, 1.0)
    val skyTarget = when {
        minutes < 450 -> hexColor(0xFFB7A8)
        minutes < 1050 -> hexColor(0x5AAEF7)
        minutes < 1230 -> hexColor(0xFF9466)
        else -> hexColor(0x1B2A6B)
    }
    val sky by animateColorAsState(skyTarget, tween(400), label = "sky")
    val night by animateFloatAsState(if (isNight) 1f else 0f, tween(400), label = "night")
    val cloud by animateFloatAsState(if (minutes >= 450 && minutes < 1050) 1f else 0f, tween(400), label = "cloud")
    val hill0 by animateColorAsState(if (isNight) hexColor(0x14463A) else hexColor(0x3FA36B), tween(400), label = "h0")
    val hill1 by animateColorAsState(if (isNight) hexColor(0x0E3029) else hexColor(0x2E8555), tween(400), label = "h1")

    BoxWithConstraints(modifier.clip(RoundedCornerShape(24.dp)).background(sky)) {
        val w = maxWidth
        val h = maxHeight
        val sunX = 40.dp + (w - 80.dp) * progress.toFloat()
        val sunYTarget = if (isNight) h + 60.dp else h * 0.72f - h * (sin(PI * progress) * 0.56).toFloat()
        val sunY by androidx.compose.animation.core.animateDpAsState(sunYTarget, Anim.snappy(), label = "sunY")
        val sunXA by androidx.compose.animation.core.animateDpAsState(sunX, Anim.snappy(), label = "sunX")

        // Stars and moon
        Box(Modifier.fillMaxSize().graphicsLayer { alpha = night }) {
            star(w * 0.12f, h * 0.16f, 6.dp)
            star(w * 0.36f, h * 0.3f, 4.dp)
            star(w * 0.58f, h * 0.13f, 5.dp)
            star(w * 0.88f, h * 0.38f, 4.dp)
            Icon(Icons.Rounded.DarkMode, null, tint = hexColor(0xFDF6E3),
                modifier = Modifier.offset(w * 0.76f - 25.dp, h * 0.22f - 25.dp).size(50.dp))
        }
        // Daytime cloud
        Box(Modifier.offset(w * 0.22f - 43.dp, h * 0.3f - 14.dp).size(86.dp, 28.dp).graphicsLayer { alpha = cloud }
            .clip(CircleShape).background(Color.White))
        // Sun
        Box(Modifier.offset(sunXA - 42.dp, sunY - 42.dp).size(84.dp).clip(CircleShape).background(hexColor(0xFFC533, 0.28f)),
            contentAlignment = Alignment.Center) {
            Box(Modifier.size(64.dp).clip(CircleShape).background(hexColor(0xFFC533)))
        }
        // Hills
        Box(Modifier.fillMaxSize().background(hill0, HillShape(0)))
        Box(Modifier.fillMaxSize().background(hill1, HillShape(1)))
    }
}

@Composable
private fun star(x: Dp, y: Dp, size: Dp) {
    Box(Modifier.offset(x - size / 2, y - size / 2).size(size).clip(CircleShape).background(Color.White))
}

class HillShape(private val seed: Int) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val k = density.density
        val base = size.height
        val top = size.height - size.height * (if (seed == 0) 0.3f else 0.18f)
        val p = Path().apply {
            moveTo(0f, base)
            lineTo(0f, top + 20 * k)
            if (seed == 0) {
                cubicTo(size.width * 0.3f, top - 50 * k, size.width * 0.65f, top + 46 * k, size.width, top + 6 * k)
            } else {
                cubicTo(size.width * 0.35f, top - 34 * k, size.width * 0.7f, top + 38 * k, size.width, top + 12 * k)
            }
            lineTo(size.width, base)
            close()
        }
        return Outline.Generic(p)
    }
}

fun momentLabel(minutes: Int): String = when {
    minutes < 540 -> L("At breakfast")
    minutes < 720 -> L("In the morning")
    minutes < 840 -> L("At lunch break")
    minutes < 1080 -> L("In the afternoon")
    minutes < 1230 -> L("In the evening")
    else -> L("Before bed")
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ReminderScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val context = LocalContext.current
    /** Slider position, continuous. The kept time is rounded to the quarter hour. */
    var raw by remember { mutableFloatStateOf(user.profile.reminderMinutes.toFloat()) }
    val minutes = (raw / 15f).roundToInt() * 15
    var lastTick by remember { mutableIntStateOf(minutes) }
    // One tick per quarter hour crossed, not on every finger move.
    LaunchedEffect(minutes) { if (minutes != lastTick) { lastTick = minutes; Haptics.selection() } }

    fun finish(granted: Boolean, chosen: Int) {
        user.update { it.copy(reminderOn = granted) }
        if (granted) {
            Reminder.scheduleDaily(context, chosen)
            Haptics.success()
        }
        onNext()
    }

    var pending by remember { mutableIntStateOf(0) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        finish(granted, pending)
    }

    fun activate() {
        val chosen = minutes
        user.update { it.copy(reminderMinutes = chosen) }
        if (Build.VERSION.SDK_INT >= 33 && !Reminder.isAllowed(context)) {
            pending = chosen
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            finish(true, chosen)
        }
    }

    fun skip() {
        user.update { it.copy(reminderMinutes = minutes, reminderOn = false) }
        onNext()
    }

    Box(Modifier.navigationBarsPadding()) {
    OnbScaffold(
        title = L("What time would you like to do your daily learning?"),
        subtitle = L("Just one notification a day, promise."),
        spoken = true,
        cta = L("Remind me at %@", formatMinutes(minutes)),
        onNext = { activate() },
        secondaryTitle = L("Later"),
        onSecondary = { skip() },
    ) {
        SunScene(raw.toDouble(), Modifier.fillMaxWidth().height(168.dp).enter(2.0))
        Column(Modifier.fillMaxWidth().enter(3.0), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(formatMinutes(minutes), style = figtree(40, FontWeight.Bold).copy(fontFeatureSettings = "tnum"), color = Palette.ink)
            Text(momentLabel(minutes), style = figtree(15), color = Palette.muted)
        }
        Column(Modifier.fillMaxWidth().enter(4.0), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            // Same look as the iOS slider: thin track, round white thumb.
            Slider(
                value = raw, onValueChange = { raw = it }, valueRange = 360f..1380f,
                modifier = Modifier.semantics { contentDescription = L("Reminder time") },
                thumb = {
                    Box(Modifier.size(28.dp).shadow(4.dp, CircleShape).clip(CircleShape).background(Color.White))
                },
                track = { state ->
                    val fraction = (state.value - state.valueRange.start) / (state.valueRange.endInclusive - state.valueRange.start)
                    Canvas(Modifier.fillMaxWidth().height(4.dp)) {
                        val y = size.height / 2
                        drawLine(Palette.line, Offset(0f, y), Offset(size.width, y), size.height, StrokeCap.Round)
                        drawLine(Palette.blue, Offset(0f, y), Offset(size.width * fraction, y), size.height, StrokeCap.Round)
                    }
                },
            )
            Row(Modifier.fillMaxWidth()) {
                listOf(L("6 AM"), L("noon"), L("6 PM"), L("11 PM")).forEachIndexed { i, t ->
                    if (i > 0) Spacer(Modifier.weight(1f))
                    Text(t, style = AType.caption, color = Palette.muted)
                }
            }
        }
    }
    }
}

// MARK: The widget: the artwork of the day without opening the app

/** Phone outline around a drawn screen. */
@Composable
private fun PhoneMockup(modifier: Modifier = Modifier, screen: @Composable () -> Unit) {
    Box(
        modifier.aspectRatio(0.5f, matchHeightConstraintsFirst = true).clip(RoundedCornerShape(41.dp)).background(Palette.blueDark).padding(7.dp)
    ) {
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(34.dp))) { screen() }
        Box(Modifier.align(Alignment.TopCenter).padding(top = 10.dp).size(76.dp, 22.dp).clip(CircleShape).background(Color.Black))
    }
}

@Composable
fun WidgetScreen(onNext: () -> Unit) {
    val content = LocalContent.current
    /** False: Lock Screen. True: Home Screen. */
    var home by remember { mutableStateOf(OnboardingDebug.flag("onbWidgetHome")) }
    var popped by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val artwork = content.artwork("nuit") ?: content.artworks.firstOrNull()
    val today = remember { LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE d MMMM", AppLanguage.locale)) }

    LaunchedEffect(Unit) {
        launch { delay(900); Haptics.soft() }
        delay(700)
        popped = true
    }
    val pop by animateFloatAsState(if (popped) 1f else 0f, Anim.settle(), label = "pop")

    Column(
        Modifier.fillMaxSize().background(Palette.bg).navigationBarsPadding().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(Modifier.enter(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(L("Your daily masterpiece, without even opening the app."), style = AType.title, color = Palette.ink, textAlign = TextAlign.Center)
            Text(L("On your Lock Screen, and on your Home Screen."), style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center)
        }

        PhoneMockup(Modifier.padding(top = 20.dp).heightIn(max = 430.dp).enter(2.0)) {
            AnimatedContent(home, transitionSpec = { fadeIn(Anim.settle()) togetherWith fadeOut(Anim.settle()) }, label = "phone") { isHome ->
                if (isHome) {
                    // A real Home Screen with the Artura widget (screenshot taken on a phone).
                    Image(painterResource(drawableId("widget_home")), null, contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize().graphicsLayer {
                            val s = 1.04f - 0.04f * pop; scaleX = s; scaleY = s; alpha = pop
                        })
                } else {
                    LockScreen(today, artwork?.image, artwork?.title ?: "", artwork?.artist ?: "", pop)
                }
            }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))

        PillButton(if (home) L("Continue") else L("And on the Home Screen?")) {
            if (home) onNext() else {
                popped = false
                home = true
                scope.launch { delay(250); popped = true }
            }
        }
    }
}

@Composable
private fun LockScreen(today: String, image: String?, title: String, artist: String, pop: Float) {
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(hexColor(0x16294A), hexColor(0x3D5E93))))) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(today, style = figtree(13, FontWeight.Medium), color = Color.White.copy(alpha = 0.9f), maxLines = 1, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 44.dp))
            Text("9:41", style = androidx.compose.ui.text.TextStyle(fontSize = 62.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.SansSerif, lineHeight = 66.sp),
                color = Color.White)
            // The Lock Screen widget
            Row(
                Modifier.padding(horizontal = 10.dp).padding(top = 8.dp).fillMaxWidth()
                    .graphicsLayer { val s = 0.86f + 0.14f * pop; scaleX = s; scaleY = s; alpha = pop }
                    .clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.16f))
                    .border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(18.dp)).padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (image != null) ArtImage(image, Modifier.size(40.dp).clip(RoundedCornerShape(9.dp)), small = true)
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(L("Artwork of the day"), style = figtree(10, FontWeight.SemiBold), color = Color.White.copy(alpha = 0.75f), maxLines = 1)
                    Text(title, style = figtree(13, FontWeight.Bold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(artist, style = figtree(11), color = Color.White.copy(alpha = 0.8f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth().padding(horizontal = 26.dp)) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)))
                Spacer(Modifier.weight(1f))
                Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)))
            }
            Box(Modifier.padding(top = 10.dp, bottom = 8.dp).size(84.dp, 4.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.8f)))
        }
    }
}

// MARK: Made by art lovers, for art lovers

/** The in-app rating prompt is asked once per launch, even if the visitor comes back to this screen. */
private var ratingAsked = false

/** A word from the team, and the Google Play rating prompt half a second after the screen appears. */
@Composable
fun MadeByScreen(onNext: () -> Unit) {
    val context = LocalContext.current
    LaunchedEffect(Unit) {
        if (ratingAsked) return@LaunchedEffect
        delay(500)
        var c = context
        while (c !is Activity && c is ContextWrapper) c = c.baseContext
        val activity = c as? Activity ?: return@LaunchedEffect
        ratingAsked = true
        Analytics.track("rating_prompt", mapOf("from" to "onboarding"))
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
        }
    }
    StoryScaffold(
        image = "ill_amateurs",
        title = L("Artura was made by art lovers, for art lovers."),
        subtitle = L("If you like it too, a few stars help other curious minds find us."),
        onNext = onNext,
    )
}

// MARK: Loading: building your program

@Composable
fun LoadingScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val rows = listOf(
        L("Analyzing your answers"),
        L("Setting your starting level"),
        L("Choosing your first lesson"),
        L("Scheduling your reminder"),
    )
    val stepMs = 950
    /** Progress from 0 to 100. */
    var target by remember { mutableFloatStateOf(0f) }
    val progress by animateFloatAsState(target, tween(stepMs, easing = androidx.compose.animation.core.FastOutSlowInEasing), label = "progress")
    var stage by remember { mutableIntStateOf(0) }
    var shown by remember { mutableIntStateOf(0) }
    val isDone = stage >= rows.size
    val name = user.profile.firstName
    val title = if (!name.isNullOrEmpty()) L("%@, we're building your program", name) else L("Building your program")

    LaunchedEffect(Unit) {
        launch {
            for (i in 1..floatingSpaceCount) { delay(if (i == 1) 500 else 300); shown = maxOf(shown, i) }
        }
        for (i in 1..rows.size) {
            delay(if (i == 1) 500 else 200)
            target = i * 100f / rows.size
            delay(stepMs.toLong())
            stage = i
            if (i == rows.size) Haptics.success() else Haptics.press()
        }
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        // Paintings and a sculpture float behind, coming in as the loading progresses.
        FloatingSpace(Modifier.graphicsLayer { alpha = 0.5f }, shown = shown, withSculpture = true)

        Column(Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 24.dp).padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f).heightIn(min = 12.dp))
            // The Mona Lisa at the center of the progress ring
            Box(Modifier.size(164.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.fillMaxSize().clip(CircleShape).background(Palette.mist)) {
                    Image(painterResource(drawableId("joconde")), null, contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize().padding(top = 14.dp))
                }
                Canvas(Modifier.fillMaxSize()) {
                    val sw = 12.dp.toPx()
                    drawCircle(Palette.line, radius = size.minDimension / 2, style = Stroke(sw))
                    drawArc(Palette.blue, -90f, 360f * progress / 100f, false, style = Stroke(sw, cap = StrokeCap.Round),
                        topLeft = Offset(0f, 0f), size = size)
                }
            }
            Text("${progress.roundToInt()}%", style = figtree(40, FontWeight.Bold), color = Palette.ink, modifier = Modifier.padding(top = 14.dp))
            Column(
                Modifier.padding(top = 6.dp).background(Palette.bg.copy(alpha = 0.92f), RoundedCornerShape(20.dp)).padding(horizontal = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(title, style = figtree(26, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
                Text(L("Based on your answers, just for you."), style = AType.body, color = Palette.muted, textAlign = TextAlign.Center)
            }
            Column(
                Modifier.padding(top = 20.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Palette.card)
                    .padding(horizontal = 16.dp, vertical = 6.dp)
            ) {
                rows.forEachIndexed { i, row ->
                    val done = stage > i
                    val active = stage == i
                    Row(Modifier.height(46.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(26.dp).clip(CircleShape).background(if (done) Palette.green else if (active) Palette.mist else Palette.line),
                            contentAlignment = Alignment.Center) {
                            androidx.compose.animation.AnimatedVisibility(done, enter = scaleIn() + fadeIn()) {
                                Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                            }
                            if (active) CircularProgressIndicator(color = Palette.blue, strokeWidth = 2.dp, modifier = Modifier.size(12.dp))
                        }
                        Text(row, style = figtree(15, if (done || active) FontWeight.SemiBold else FontWeight.Normal),
                            color = if (done || active) Palette.ink else Palette.muted, modifier = Modifier.weight(1f))
                    }
                }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
            if (isDone) {
                Box(Modifier.enter()) { PillButton(L("See my program")) { onNext() } }
            } else {
                Box(Modifier.height(59.dp), contentAlignment = Alignment.Center) {
                    Text(L("Just a moment…"), style = AType.small, color = Palette.muted)
                }
            }
        }
    }
}

// MARK: Your program

/** Row of the five avatars (used in the onboarding and the profile). */
@Composable
fun AvatarPicker(selection: Int, onSelect: (Int) -> Unit, size: Dp = 56.dp, onPick: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        avatarImages.forEachIndexed { i, image ->
            val selected = selection == i
            val s by animateFloatAsState(if (selected) 1.04f else 1f, Anim.bouncy(), label = "avatar")
            Box(
                Modifier
                    .semantics { contentDescription = avatarLabels[i] }
                    .pressable {
                        Haptics.selection()
                        onSelect(i)
                        onPick?.invoke()
                    }
                    .graphicsLayer { scaleX = s; scaleY = s }
                    .border(3.dp, if (selected) Palette.blue else Color.Transparent, CircleShape)
                    .padding(3.dp)
            ) {
                ArtImage(image, Modifier.size(size).clip(CircleShape))
            }
            if (i < avatarImages.size - 1) Spacer(Modifier.weight(1f))
        }
    }
}

/** Soft mauve behind the avatar block (a getter, so it follows dark mode). */
private val mauve: Color get() = if (Palette.isDark) hexColor(0x2A2340) else hexColor(0xEDE3FF)

/** Goals are stored in English (see MotivationScreen); this is the label shown. */
private fun goalName(goal: String): String = when (goal) {
    "Learn about art" -> L("Learn about art")
    "Become more cultured" -> L("Become more cultured")
    "Have new things to talk about" -> L("Have new things to talk about")
    "Prepare for an exam" -> L("Prepare for an exam")
    "Just for fun" -> L("Just for fun")
    else -> goal
}

@Composable
fun PlanScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    var picking by remember { mutableStateOf(false) }
    val profile = user.profile
    /** The movement of the first lesson: the first path of the program. */
    val movement = content.movement(content.artwork(profile.firstCourse)?.movementId) ?: content.movements.firstOrNull()

    val goals = profile.goals ?: emptyList()
    val goalLabel = (goals.firstOrNull() ?: profile.goal)?.let { first ->
        val shown = goalName(first)
        if (goals.size > 1) "$shown (+${goals.size - 1})" else shown
    } ?: L("Not set")
    val total = profile.minutes * 30
    val hours = if (total % 60 == 0) L("%@ h", "${total / 60}") else L("%@ h %@", "${total / 60}", "${total % 60}")

    Box(Modifier.navigationBarsPadding()) {
    OnbScaffold(title = L("In 30 days"), subtitle = L("Here's where you'll be, at your own pace."), cta = L("Sounds good"), onNext = onNext) {
        Box(
            Modifier.fillMaxWidth().height(84.dp).enter(1.0).clip(RoundedCornerShape(16.dp)).background(mauve),
            contentAlignment = Alignment.Center,
        ) {
            AnimatedContent(picking, transitionSpec = { fadeIn(Anim.gentle()) togetherWith fadeOut(Anim.gentle()) }, label = "avatar") { isPicking ->
                if (isPicking) {
                    Box(Modifier.padding(horizontal = 12.dp)) {
                        AvatarPicker(profile.avatar, { a -> user.update { it.copy(avatar = a) } }, 52.dp) { picking = false }
                    }
                } else {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        ArtImage(avatarImages[minOf(profile.avatar, avatarImages.size - 1)], Modifier.size(60.dp).clip(CircleShape))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(L("Your avatar"), style = AType.bodyStrong, color = Palette.ink)
                            Text(L("Shown on your profile"), style = AType.caption, color = Palette.muted)
                        }
                        Box(
                            Modifier.height(44.dp).pressable { Haptics.tap(); picking = true }.clip(CircleShape).background(Palette.bg)
                                .padding(horizontal = 16.dp),
                            contentAlignment = Alignment.Center,
                        ) { Text(L("Change"), style = figtree(14, FontWeight.SemiBold), color = Palette.blueText) }
                    }
                }
            }
        }

        val cover = movement?.let { content.artwork(it.cover) }
        if (movement != null && cover != null) {
            Row(Modifier.fillMaxWidth().enter(2.0).clip(RoundedCornerShape(16.dp)).background(Palette.yellow),
                verticalAlignment = Alignment.CenterVertically) {
                ArtImage(cover.image, Modifier.size(104.dp, 112.dp))
                Column(Modifier.weight(1f).padding(horizontal = 14.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(L("Your first path"), style = figtree(12, FontWeight.SemiBold), color = hexColor(0x2D2C2B))
                    Text(movement.name, style = AType.cardTitle, color = hexColor(0x2D2C2B))
                    Text(movement.summary, style = AType.caption, color = hexColor(0x2D2C2B))
                }
            }
        }

        Row(Modifier.fillMaxWidth().enter(3.0), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Projection("${minOf(30, content.artworks.size)}", L("artworks"), Modifier.weight(1f))
            Projection(hours, L("of looking"), Modifier.weight(1f))
            Projection("${maxOf(1, minOf(content.movements.size, 3))}", L("movements"), Modifier.weight(1f))
        }

        Column(Modifier.fillMaxWidth().enter(4.0).clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 16.dp)) {
            Recap(L("Goal"), goalLabel)
            HorizontalDivider(color = Palette.line)
            Recap(L("Every day"), L("%@ min", "${profile.minutes}"))
            HorizontalDivider(color = Palette.line)
            Recap(L("Reminder"), if (profile.reminderOn) formatMinutes(profile.reminderMinutes) else L("Off"))
        }
    }
    }
}

@Composable
private fun Projection(value: String, label: String, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(16.dp)).background(Palette.mist).padding(horizontal = 12.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, style = figtree(24, FontWeight.SemiBold), color = Palette.ink, maxLines = 1, softWrap = false)
        Text(label, style = AType.small, color = Palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun Recap(label: String, value: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = AType.small, color = Palette.muted)
        Spacer(Modifier.width(8.dp).weight(1f))
        Text(value, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.End, maxLines = 2)
    }
}

// MARK: Social proof: learners and reviews

/** A laurel branch (SF Symbols "laurel.leading" / "laurel.trailing"). */
@Composable
private fun Laurel(mirrored: Boolean, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(40.dp, 62.dp).graphicsLayer { if (mirrored) scaleX = -1f }) {
        val w = size.width
        val h = size.height
        val stem = Path().apply {
            moveTo(w * 0.85f, h * 0.98f)
            quadraticTo(w * 0.05f, h * 0.7f, w * 0.55f, h * 0.04f)
        }
        drawPath(stem, color, style = Stroke(2.2.dp.toPx(), cap = StrokeCap.Round))
        val leaves = 6
        for (i in 0 until leaves) {
            val t = (i + 0.6f) / (leaves + 0.4f)
            // Point on the quadratic stem
            val x = (1 - t) * (1 - t) * w * 0.85f + 2 * (1 - t) * t * w * 0.05f + t * t * w * 0.55f
            val y = (1 - t) * (1 - t) * h * 0.98f + 2 * (1 - t) * t * h * 0.7f + t * t * h * 0.04f
            val lw = w * 0.42f
            val lh = w * 0.18f
            rotate(-55f + 10f * i, Offset(x, y)) {
                drawOval(color, Offset(x - lw, y - lh / 2), Size(lw, lh))
            }
            rotate(35f - 6f * i, Offset(x, y)) {
                drawOval(color, Offset(x, y - lh / 2), Size(lw * 0.85f, lh * 0.9f))
            }
        }
    }
}

@Composable
fun SocialProofScreen(onNext: () -> Unit) {
    var stars by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        delay(600)
        for (i in 1..5) { delay(140); stars = i; Haptics.whisper() }
    }

    Box(Modifier.navigationBarsPadding()) {
    OnbScaffold(title = L("You're in good company"), cta = L("Join them"), onNext = onNext) {
        // The number, between two laurels
        Column(
            Modifier.fillMaxWidth().enter(2.0)
                .semantics { contentDescription = L("More than %@ learners, rated %@ out of 5 on Google Play", SocialProof.learners, SocialProof.rating) }
                .clip(RoundedCornerShape(24.dp)).background(Palette.mistLight).border(1.dp, Palette.mist, RoundedCornerShape(24.dp))
                .padding(vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Laurel(false, Palette.yellow)
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("+ ${SocialProof.learners}", style = figtree(38, FontWeight.Bold), color = Palette.ink, maxLines = 1)
                    Text(L("learners"), style = figtree(17, FontWeight.SemiBold), color = Palette.muted)
                }
                Laurel(true, Palette.yellow)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(SocialProof.rating, style = figtree(17, FontWeight.Bold), color = Palette.ink)
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    for (i in 0 until 5) {
                        val on by animateFloatAsState(if (i < stars) 1f else 0f, Anim.snappy(), label = "star$i")
                        Icon(Icons.Rounded.Star, null, tint = Palette.yellow,
                            modifier = Modifier.size(17.dp).graphicsLayer { val s = 0.5f + 0.5f * on; scaleX = s; scaleY = s; alpha = on })
                    }
                }
                Text(L("on Google Play"), style = figtree(15), color = Palette.muted)
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SocialProof.reviews.forEachIndexed { i, review ->
                Row(
                    Modifier.fillMaxWidth().enter(i * 1.5 + 4).clip(RoundedCornerShape(20.dp)).background(Palette.card).padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    ArtImage(avatarImages[i % avatarImages.size], Modifier.size(40.dp).clip(CircleShape))
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                            repeat(5) { Icon(Icons.Rounded.Star, null, tint = Palette.yellow, modifier = Modifier.size(12.dp)) }
                        }
                        Text(L("“%@”", review), style = figtree(15, FontWeight.Medium), color = Palette.ink)
                    }
                }
            }
        }
    }
    }
}

// MARK: Account

@Composable
fun AccountScreen(onBack: () -> Unit, onNext: () -> Unit) {
    var message by remember { mutableStateOf<String?>(null) }

    Column(Modifier.fillMaxSize().background(Palette.bg).navigationBarsPadding().padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        // Grainy illustration at the top, under a tilted arc.
        Box(Modifier.fillMaxWidth().height(320.dp)) {
            ArtImage("ill_galerie", Modifier.fillMaxSize().clip(ArcHeaderShape), anchor = Offset(0.5f, 0.7f))
            Box(
                Modifier.statusBarsPadding().padding(start = 16.dp, top = 8.dp).size(44.dp)
                    .semantics { contentDescription = L("Back") }
                    .pressable(onClick = onBack).clip(CircleShape).background(Palette.bg),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBackIos, null, tint = Palette.ink, modifier = Modifier.size(18.dp).offset(x = 3.dp))
            }
        }

        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-24).dp).enter(1.0),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(L("Keep your streak and your collection"), style = figtree(28, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
            Text(L("An account so you don't lose anything if you change phones."), style = AType.body, color = Palette.muted, textAlign = TextAlign.Center)
        }

        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))

        Column(
            Modifier.padding(horizontal = 24.dp).enter(3.0),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            message?.let { Text(it, style = AType.caption, color = Palette.red, textAlign = TextAlign.Center) }
            SignInButtons(message, { message = it }, onNext)
            TextLinkButton(L("Continue without an account"), onClick = onNext)
            Text(L("By continuing, you agree to the Terms of Use and the Privacy Policy."), style = figtree(12),
                color = Palette.muted, textAlign = TextAlign.Center)
        }
    }
}

// MARK: - Sign in with Google

/**
 * "Continue with Google", used by the onboarding and the profile. The identity is kept on the phone at once
 * and `onDone` is called; the Supabase account (progress saved online) is opened in the background, so a
 * slow network never blocks the screen. (No Apple sign-in on Android.)
 */
@Composable
fun SignInButtons(message: String?, onMessage: (String?) -> Unit, onDone: () -> Unit) {
    val user = LocalUser.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    /** The Google button only appears in a release build if sign-in is configured. */
    val showsGoogle = GoogleAuth.isConfigured || OnboardingDebug.isDebug

    fun signIn() {
        onMessage(null)
        if (!GoogleAuth.isConfigured) {
            Haptics.warning()
            onMessage("Google sign-in isn't set up yet (webClientId missing in GoogleAuth.kt).")
            return
        }
        val activity = context as? Activity ?: return
        busy = true
        scope.launch {
            try {
                val account = GoogleAuth.signIn(activity)
                user.update { p ->
                    p.copy(googleUserId = account.userId,
                        firstName = if (p.firstName.isNullOrEmpty() && account.firstName != null) account.firstName else p.firstName)
                }
                busy = false
                Haptics.success()
                // Opened in the background: the app scope keeps going after this screen leaves.
                kotlinx.coroutines.MainScope().launch { user.connectAccount("google", account.idToken, account.rawNonce) }
                onDone()
            } catch (_: GoogleAuth.Cancelled) {
                busy = false
            } catch (_: Exception) {
                busy = false
                Haptics.warning()
                onMessage(L("Google sign-in failed. Please try again in a moment."))
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (showsGoogle) {
            Row(
                Modifier.fillMaxWidth().height(56.dp).pressable(enabled = !busy) { signIn() }
                    .clip(CircleShape).background(Palette.bg).border(1.5.dp, Palette.lip, CircleShape),
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (busy) {
                    CircularProgressIndicator(color = Palette.ink, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                } else {
                    Image(painterResource(drawableId("google_g")), null, Modifier.size(20.dp))
                    Text(L("Continue with Google"), style = androidx.compose.ui.text.TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Medium), color = Palette.ink)
                }
            }
        }
    }
}

