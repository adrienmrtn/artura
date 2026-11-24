package com.vikstudios.artura.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.core.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.cos
import kotlin.math.sin

// Port of OnboardingIntro.swift.

// MARK: Shared helpers

/** Desaturates what is drawn (0 = black and white, 1 = untouched), like SwiftUI `.saturation()`. */
fun Modifier.saturation(amount: Float): Modifier = drawWithContent {
    if (amount >= 1f) {
        drawContent()
    } else {
        val paint = Paint().apply { colorFilter = ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(amount) }) }
        drawIntoCanvas { canvas ->
            canvas.saveLayer(androidx.compose.ui.geometry.Rect(Offset.Zero, size), paint)
            drawContent()
            canvas.restore()
        }
    }
}

/** A tap anywhere on the area, without ripple. */
fun Modifier.tapAnywhere(onTap: () -> Unit): Modifier = clickable(MutableInteractionSource(), null, onClick = onTap)

/** Slow back-and-forth value between 1 and `to` (an illustration that "breathes"). */
@Composable
fun breathingZoom(to: Float, durationMs: Int): Float {
    val v by rememberInfiniteTransition(label = "breathe").animateFloat(
        1f, to, infiniteRepeatable(tween(durationMs), RepeatMode.Reverse), label = "zoom")
    return v
}

/** Fades and lifts the element in when `shown` becomes true (`.opacity` + `.offset(y:)` with `.settle`). */
@Composable
fun Modifier.reveal(shown: Boolean, distance: Float = 18f): Modifier {
    val t by animateFloatAsState(if (shown) 1f else 0f, Anim.settle(), label = "reveal")
    return graphicsLayer { alpha = t; translationY = (1 - t) * distance * density }
}

// MARK: Welcome

@Composable
fun WelcomeScreen(onNext: () -> Unit, onLogin: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().navigationBarsPadding()) {
            HeroScaffold(
                image = "ill_hero", imageHeight = 460.dp, cta = L("Get started"), onNext = onNext,
                secondaryTitle = L("I already have an account"), onSecondary = onLogin,
            ) {
                Text("ARTURA", style = figtree(13, FontWeight.Bold).copy(letterSpacing = 3.sp), color = Palette.blue,
                    modifier = Modifier.enter(0.0))
                Text(L("Finally learn art"), style = figtree(36, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center,
                    modifier = Modifier.enter(1.0))
                Text(L("5 minutes a day. Sessions tailored to you."), style = figtree(17), color = Palette.muted,
                    textAlign = TextAlign.Center, modifier = Modifier.enter(2.5))
            }
        }
        Box(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(end = 16.dp, top = 8.dp)) {
            LanguageMenu()
        }
    }
}

// MARK: Language

/** Menu to switch the app's language, shown on the welcome screen. */
@Composable
fun LanguageMenu() {
    var open by remember { mutableStateOf(false) }
    val selection = AppLanguage.code
    Box {
        Row(
            Modifier.clip(CircleShape).background(Palette.bg.copy(alpha = 0.72f))
                .pressable { open = true }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(Icons.Rounded.Language, L("Language"), tint = Palette.ink, modifier = Modifier.size(16.dp))
            Text(AppLanguage.name(selection), style = figtree(14, FontWeight.SemiBold), color = Palette.ink)
            Icon(Icons.Rounded.KeyboardArrowDown, null, tint = Palette.ink, modifier = Modifier.size(16.dp))
        }
        DropdownMenu(open, onDismissRequest = { open = false }, containerColor = Palette.bg) {
            AppLanguage.all.forEach { code ->
                DropdownMenuItem(
                    text = { Text(AppLanguage.name(code), style = AType.body, color = Palette.ink) },
                    trailingIcon = if (code == selection) {
                        { Icon(Icons.Rounded.Check, null, tint = Palette.ink, modifier = Modifier.size(18.dp)) }
                    } else null,
                    onClick = {
                        open = false
                        if (code != selection) {
                            Haptics.selection()
                            AppLanguage.set(code)
                        }
                    },
                )
            }
        }
    }
}

/** "Which language?": the full list of the app's languages, each written in its own language. */
@Composable
fun LanguageScreen(onNext: () -> Unit) {
    val selection = AppLanguage.code
    OnbScaffold(title = L("Which language?"), subtitle = L("You can change it anytime in Settings."), spoken = true, onNext = onNext) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AppLanguage.all.forEach { code ->
                ChoiceRow(
                    title = AppLanguage.name(code),
                    subtitle = nameInCurrentLanguage(code, selection),
                    selected = selection == code,
                ) { AppLanguage.set(code) }
            }
        }
    }
}

/** "Allemand" under "Deutsch" when the app is in French; nothing for the current language. */
private fun nameInCurrentLanguage(code: String, selection: String): String? {
    if (code == selection) return null
    val current: Locale = AppLanguage.locale
    val name = Locale.forLanguageTag(code).getDisplayName(current).ifEmpty { return null }
    val shown = name.replaceFirstChar { it.titlecase(current) }
    return if (shown == AppLanguage.name(code)) null else shown
}

// MARK: One masterpiece a day (wall of paintings)

@Composable
fun DailyScreen(onNext: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Palette.bg).padding(top = 8.dp, bottom = 16.dp)) {
        FloatingWall(Modifier.enter())
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(L("One masterpiece a day"), style = figtree(34, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center,
                modifier = Modifier.enter(2.0))
            Text(L("Get cultured without even noticing."), style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center,
                modifier = Modifier.enter(3.0))
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 24.dp).enter(5.0),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Proof(SocialProof.learners, L("people already learning"), Modifier.weight(1f)) {
                Icon(Icons.Rounded.People, null, tint = Palette.blue, modifier = Modifier.size(18.dp))
            }
            Proof(SocialProof.rating, L("average rating"), Modifier.weight(1f)) {
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    repeat(5) { Icon(Icons.Rounded.Star, null, tint = Palette.yellow, modifier = Modifier.size(13.dp)) }
                }
            }
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        Box(Modifier.padding(horizontal = 24.dp)) { com.vikstudios.artura.core.PillButton(L("Continue")) { onNext() } }
    }
}

@Composable
private fun Proof(value: String, label: String, modifier: Modifier, mark: @Composable () -> Unit) {
    Column(
        modifier.clip(RoundedCornerShape(20.dp)).background(Palette.card).padding(vertical = 14.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.height(16.dp), contentAlignment = Alignment.Center) { mark() }
        Text(value, style = figtree(26, FontWeight.Bold), color = Palette.ink)
        Text(label, style = AType.caption, color = Palette.muted, textAlign = TextAlign.Center)
    }
}

// MARK: A museum in your pocket

@Composable
fun PocketMuseumScreen(onNext: () -> Unit) {
    StoryScaffold(
        image = "ill_musee",
        title = L("Artura is a museum in your pocket."),
        subtitle = L("Built for art lovers, and for everyone who wants to become one."),
        onNext = onNext,
    )
}

// MARK: At the museum too

@Composable
fun PhotoScreen(onNext: () -> Unit) {
    StoryScaffold(
        image = "ill_photo",
        tag = L("At the museum?"),
        title = L("Snap any artwork. Artura explains it."),
        subtitle = L("And save the ones you want to remember to your collection."),
        onNext = onNext,
    )
}

// MARK: Quotes: why Artura

data class Quote(val image: String, val text: String, val author: String, val role: String) {
    companion object {
        // Quotes to be checked (source and translation) before release.
        val all: List<Quote>
            get() = listOf(
                Quote("portrait_klee", L("Art does not reproduce the visible; it makes visible."), "Paul Klee", L("Painter")),
                Quote("portrait_nietzsche", L("We have art in order not to die of the truth."), "Friedrich Nietzsche", L("Philosopher")),
                Quote("portrait_proust", L("Through art alone are we able to emerge from ourselves."), "Marcel Proust", L("Writer")),
            )
    }
}

@Composable
fun QuotesScreen(onBack: () -> Unit, onNext: () -> Unit) {
    val quotes = remember { Quote.all }
    /** Number of quotes revealed so far, none at first: each tap brings the next one, then the screen moves on. */
    var shown by remember { mutableIntStateOf(OnboardingDebug.int("onbQuotesShown").coerceIn(0, quotes.size)) }

    fun advance() {
        if (shown < quotes.size) {
            shown++
            Haptics.soft()
        } else {
            Haptics.tap()
            onNext()
        }
    }

    Box(Modifier.fillMaxSize().background(Color.Black).tapAnywhere { advance() }) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 24.dp).padding(bottom = 16.dp)) {
            Box(
                Modifier.padding(top = 8.dp).offset(x = (-12).dp).size(44.dp).pressable { onBack() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, L("Back"), tint = Color.White, modifier = Modifier.size(32.dp))
            }
            Column(Modifier.padding(top = 12.dp).enter(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(L("This is why we built Artura"), style = AType.title, color = Color.White)
                Text(L("Art is timeless. They said it long before us."), style = AType.body, color = Color.White.copy(alpha = 0.7f))
            }
            Column(Modifier.padding(top = 36.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                quotes.forEachIndexed { i, quote ->
                    Row(Modifier.fillMaxWidth().reveal(i < shown), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        ArtImage(quote.image, Modifier.size(56.dp).clip(CircleShape).saturation(0f))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(L("“%@”", quote.text), style = serif(20f).copy(fontStyle = FontStyle.Italic), color = Color.White)
                            Text("${quote.author} · ${quote.role}", style = AType.caption, color = Color.White.copy(alpha = 0.6f))
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
            TapHint(light = true)
        }
    }
}

/** "Tap to continue", at the bottom of screens that move on with a tap anywhere. */
@Composable
fun TapHint(modifier: Modifier = Modifier, light: Boolean = false) {
    val pulse by rememberInfiniteTransition(label = "hint").animateFloat(
        0.45f, 1f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "pulse")
    Box(modifier.fillMaxWidth().height(56.dp), contentAlignment = Alignment.Center) {
        Text(L("Tap to continue"), style = figtree(15, FontWeight.SemiBold),
            color = if (light) Color.White.copy(alpha = 0.7f) else Palette.muted,
            modifier = Modifier.graphicsLayer { alpha = pulse })
    }
}

// MARK: The Mona Lisa speaks

/** "Hi, I'm Artura": the character introduces herself, right after the welcome screen. */
@Composable
fun HelloScreen(onNext: () -> Unit) {
    MascotTalkScreen(
        lines = listOf(L("Hi, I'm Artura. Every day, I'll show you one masterpiece and the story behind it.")),
        cta = L("Hi Artura!"), mascotSize = 190.dp, onNext = onNext,
    )
}

@Composable
fun QuestionsIntroScreen(onNext: () -> Unit) {
    MascotTalkScreen(
        lines = listOf(L("Let's get to know each other. A few quick questions, under a minute, to build your program.")),
        cta = L("Let's go"), onNext = onNext,
    )
}

@Composable
fun TestIntroScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val name = user.profile.firstName
    val start = if (!name.isNullOrEmpty()) L("Great, %@.", name) else L("Great.")
    // "%@" is "Great, <name>." or "Great.", followed by the rest of the sentence.
    val line = L("%@ Let's see what you already know: seven paintings, from the most famous to the hardest.", start)
    MascotTalkScreen(lines = listOf(line), cta = L("I'm ready"), onNext = onNext)
}

// MARK: Story pages revealed tap by tap

/**
 * An illustration, then a tag and a title, then a text: each tap brings the next block.
 * Once everything is there, a tap anywhere moves on.
 */
@Composable
fun TapStoryScreen(image: String, tag: String, title: String, text: String, onNext: () -> Unit) {
    /** Blocks revealed so far: 0 = the illustration alone, 1 = tag and title, 2 = the text. */
    var shown by remember { mutableIntStateOf(OnboardingDebug.int("onbShown").coerceIn(0, 2)) }
    val zoom = breathingZoom(1.09f, 7000)

    fun advance() {
        if (shown < 2) {
            shown++
            Haptics.soft()
        } else {
            Haptics.tap()
            onNext()
        }
    }

    Column(
        Modifier.fillMaxSize().background(Palette.bg).tapAnywhere { advance() }.padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ArtImage(image, Modifier.fillMaxWidth().weight(1f, fill = false).heightIn(min = 180.dp, max = 330.dp)
            .enter().clip(RoundedCornerShape(28.dp)), zoom = zoom)
        Column(
            Modifier.padding(top = 28.dp).reveal(shown >= 1),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TagPill(tag)
            Text(title, style = AType.title, color = Palette.ink, textAlign = TextAlign.Center)
        }
        Text(text, style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp).reveal(shown >= 2))
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        TapHint()
    }
}

// MARK: The Chicago study

@Composable
fun StudyScreen(onNext: () -> Unit) {
    TapStoryScreen(
        image = "ill_regard",
        tag = L("A study at the Art Institute of Chicago"),
        title = L("26 seconds in front of a painting"),
        text = L("That's how long a visitor looks at a masterpiece, on average. Barely enough to read the label."),
        onNext = onNext,
    )
}

// MARK: Looking can be learned

@Composable
fun LearnToLookScreen(onNext: () -> Unit) {
    TapStoryScreen(
        image = "ill_oeil",
        tag = L("Artura will help"),
        title = L("Looking can be learned"),
        text = L("Nobody is born knowing how to read a painting. Every day, I show you where to rest your eyes: a detail, a color, a gesture."),
        onNext = onNext,
    )
}

// MARK: What you'll be able to do

/** The jagged crack across a card, as polylines (0…1 coordinates): the main line, then two small branches. */
private val crackLines = listOf(
    listOf(0.0f to 0.42f, 0.14f to 0.58f, 0.27f to 0.36f, 0.41f to 0.66f, 0.5f to 0.44f,
        0.62f to 0.7f, 0.74f to 0.38f, 0.87f to 0.6f, 1.0f to 0.46f),
    listOf(0.27f to 0.36f, 0.33f to 0.08f),
    listOf(0.62f to 0.7f, 0.7f to 0.96f),
)

/** One ability: a locked box that cracks, bursts into pieces, then shows what it held. */
@Composable
private fun AbilityBox(image: String, title: String, text: String, state: Int, modifier: Modifier = Modifier) {
    var burst by remember { mutableStateOf(state >= 2) }
    LaunchedEffect(state) { if (state >= 2) burst = true }
    val burstT by animateFloatAsState(if (burst) 1f else 0f, tween(600, easing = androidx.compose.animation.core.LinearOutSlowInEasing), label = "burst")
    val openT by animateFloatAsState(if (state >= 2) 1f else 0f, Anim.gentle(), label = "open")
    val crackT by animateFloatAsState(if (state >= 1) 1f else 0f, tween(450, easing = androidx.compose.animation.core.LinearOutSlowInEasing), label = "crack")
    val shake by animateFloatAsState(if (state == 1) 3f else 0f, tween(300), label = "shake")
    val shape = RoundedCornerShape(20.dp)

    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        // What the box holds
        Row(
            Modifier.fillMaxWidth().heightIn(min = 96.dp)
                .graphicsLayer { alpha = openT; val s = 0.92f + 0.08f * openT; scaleX = s; scaleY = s }
                .clip(shape).background(Palette.mistLight).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            ArtImage(image, Modifier.size(72.dp).clip(RoundedCornerShape(16.dp)))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, style = AType.heading, color = Palette.ink)
                Text(text, style = AType.small, color = Palette.muted)
            }
        }
        // The locked lid, with its crack
        Box(
            Modifier.matchParentSize().heightIn(min = 96.dp)
                .graphicsLayer { alpha = 1f - openT; val s = 1f + 0.06f * openT; scaleX = s; scaleY = s; translationX = shake * density }
                .clip(shape).background(Palette.card),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Lock, null, tint = Palette.lip, modifier = Modifier.size(26.dp))
            Canvas(Modifier.matchParentSize().padding(horizontal = 6.dp)) {
                if (crackT <= 0f) return@Canvas
                val segs = crackLines.flatMap { line -> line.zipWithNext() }
                val lengths = segs.map { (a, b) ->
                    val dx = (b.first - a.first) * size.width; val dy = (b.second - a.second) * size.height
                    kotlin.math.sqrt(dx * dx + dy * dy)
                }
                var budget = lengths.sum() * crackT
                val stroke = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                val color = Palette.ink.copy(alpha = 0.75f)
                segs.forEachIndexed { i, (a, b) ->
                    if (budget <= 0f) return@forEachIndexed
                    val f = minOf(1f, budget / lengths[i])
                    val start = Offset(a.first * size.width, a.second * size.height)
                    val end = Offset(start.x + (b.first * size.width - start.x) * f, start.y + (b.second * size.height - start.y) * f)
                    drawLine(color, start, end, stroke.width, StrokeCap.Round)
                    budget -= lengths[i]
                }
            }
        }
        // The pieces flying away
        for (i in 0 until 12) {
            val angle = i / 12.0 * 2 * Math.PI + 0.3
            Box(
                Modifier.zIndex(2f)
                    .graphicsLayer {
                        translationX = (cos(angle) * (110 + (i * 17) % 60)).toFloat() * burstT * density
                        translationY = (sin(angle) * (60 + (i * 11) % 40)).toFloat() * burstT * density
                        rotationZ = ((i * 53) % 360) * burstT
                        alpha = if (state >= 2) 1f - burstT else 0f
                    }
                    .size((10 + (i * 7) % 12).dp, (8 + (i * 5) % 10).dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(if (i % 3 == 0) Palette.lip else Palette.card)
            )
        }
    }
}

@Composable
fun AbilitiesScreen(onNext: () -> Unit) {
    val abilities = remember {
        listOf(
            Triple("ill_oeil", L("Look"), L("Spot what matters in a painting, even one you've never seen.")),
            Triple("ill_galerie", L("Understand"), L("Who painted it, when, and why it changed everything.")),
            Triple("ill_goal_talk", L("Talk about it"), L("Have something to say at the museum, or over dinner.")),
        )
    }
    /** Boxes already open. */
    var opened by remember { mutableIntStateOf(OnboardingDebug.int("onbShown").coerceIn(0, 3)) }
    /** Index of the box that is cracking, if any. */
    var cracking by remember { mutableStateOf<Int?>(null) }
    val scope = rememberCoroutineScope()

    val title = when (opened) {
        0 -> L("Soon, you'll know how to")
        1 -> L("You'll learn how to look")
        2 -> L("…how to understand")
        else -> L("…and how to talk about it")
    }

    // Each press cracks the next box open; once all three are open, the button moves on.
    fun advance() {
        if (cracking != null) return
        if (opened >= abilities.size) { onNext(); return }
        val index = opened
        Haptics.rigid()
        cracking = index
        scope.launch {
            delay(550)
            Haptics.heavy()
            opened = index + 1
            cracking = null
        }
    }

    OnbScaffold(
        title = title, subtitle = L("A few minutes a day is all it takes."),
        ctaEnabled = cracking == null, onNext = { advance() },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            abilities.forEachIndexed { i, (image, t, text) ->
                AbilityBox(image, t, text, state = if (i < opened) 2 else if (cracking == i) 1 else 0,
                    modifier = Modifier.enter(i + 2.0))
            }
        }
    }
}

// MARK: Choose your first lesson

@Composable
fun ChooseCourseScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    /** The paintings whose lesson is a full interactive tour. */
    val courses = content.artworks.filter { a -> a.lesson.any { it.isInteractive } }.take(4)

    OnbScaffold(
        title = L("Choose your first lesson"), subtitle = L("I'll show you how it works."),
        cta = L("Start the lesson"), ctaEnabled = user.profile.firstCourse != null, onNext = onNext,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            courses.forEachIndexed { i, artwork ->
                val selected = user.profile.firstCourse == artwork.id
                val shape = RoundedCornerShape(18.dp)
                Row(
                    Modifier.fillMaxWidth().enter(i + 2.0)
                        .pressable { Haptics.selection(); user.update { it.copy(firstCourse = artwork.id) } }
                        .clip(shape)
                        .background(if (selected) Palette.mistLight else Palette.card)
                        .border(2.dp, if (selected) Palette.blue else Color.Transparent, shape)
                        .padding(10.dp).padding(end = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    ArtImage(artwork.image, Modifier.size(64.dp).clip(RoundedCornerShape(14.dp)), small = true)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(artwork.title, style = AType.bodyStrong, color = Palette.ink)
                        Text(artwork.meta, style = AType.caption, color = Palette.muted)
                    }
                    AnimatedVisibility(selected, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) { CheckBadge() }
                }
            }
        }
    }
}

// MARK: Your phone takes your attention, art gives it back

@Composable
fun AttentionScreen(onNext: () -> Unit) {
    StoryScaffold(
        image = "ill_phone",
        title = L("Your phone takes your attention. Art gives it back."),
        subtitle = L("A few minutes with a single painting, and everything slows down."),
        onNext = onNext,
    )
}

// MARK: After the guided tour

@Composable
fun AfterLessonScreen(onNext: () -> Unit) {
    MascotTalkScreen(
        lines = listOf(L("This is how you'll learn from now on. Before we finish, let's build your program.")),
        cta = L("Build my program"), onNext = onNext,
    )
}

