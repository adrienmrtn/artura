package com.vikstudios.artura.onboarding

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.QuestionMark
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.PillStyle
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Month
import java.time.format.TextStyle
import kotlin.math.abs
import kotlin.math.roundToInt

// Port of OnboardingStory.swift.

/** Fast start, very gentle end (SwiftUI `.timingCurve(0.16, 1, 0.3, 1)`). */
private val countEasing = CubicBezierEasing(0.16f, 1f, 0.3f, 1f)

// MARK: - Test: how many of these paintings can you name?

/** Entry test card: two paintings everyone knows, then five much harder ones. */
data class FlashCard(val id: String, val title: String, val artist: String, val hard: Boolean = false) {
    val image: String get() = "art_$id"

    companion object {
        val all = listOf(
            FlashCard("joconde", "Mona Lisa", "Leonardo da Vinci"),
            FlashCard("nuit", "The Starry Night", "Vincent van Gogh"),
            FlashCard("glaneuses", "The Gleaners", "Jean-François Millet"),
            FlashCard("menines", "Las Meninas", "Diego Velázquez"),
            FlashCard("grandejatte", "A Sunday Afternoon on the Island of La Grande Jatte", "Georges Seurat"),
            FlashCard("raboteurs", "The Floor Scrapers", "Gustave Caillebotte", hard = true),
            FlashCard("moine", "The Monk by the Sea", "Caspar David Friedrich", hard = true),
        )
    }
}

@Composable
fun FlashTestScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val cards = FlashCard.all
    var index by remember { mutableIntStateOf(0) }
    var dragX by remember { mutableFloatStateOf(0f) }
    var dragY by remember { mutableFloatStateOf(0f) }
    var dragging by remember { mutableStateOf(false) }
    var armed by remember { mutableStateOf(false) }
    val known = remember { mutableListOf<String>() }
    /** Cards already answered and the side they left from (dp). */
    val gone = remember { mutableStateMapOf<String, Float>() }
    val scope = rememberCoroutineScope()

    fun answer(knows: Boolean) {
        if (index !in cards.indices) return
        val current = cards[index]
        armed = false
        if (knows) { known.add(current.id); Haptics.success() } else Haptics.rigid()
        // The card leaves on the answer's side while the next one rises, in the same animation.
        val last = index >= cards.size - 1
        gone[current.id] = if (knows) 520f else -520f
        dragging = false
        dragX = 0f; dragY = 0f
        index++
        if (last) {
            user.update { it.copy(flashKnown = known.toList()) }
            scope.launch { delay(280); onNext() }
        }
    }

    Column(
        Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(Modifier.enter(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            TagPill(L("Painting %@ of %@", "${minOf(index + 1, cards.size)}", "${cards.size}"))
            Text(L("How many of these paintings can you name?"), style = AType.titleSmall, color = Palette.ink)
            Text(L("Be honest. Swipe the card, or use the buttons."), style = AType.body, color = Palette.muted)
        }

        // Stack of cards: the next one peeks out behind the top one.
        Box(Modifier.weight(1f).fillMaxWidth().padding(bottom = 34.dp).enter(2.0)) {
            cards.forEachIndexed { i, item ->
                if (i > index + 2) return@forEachIndexed
                val top = i == index
                // An answered card keeps its off-screen place: it never comes back to the center.
                val depth = maxOf(0, i - index)
                val exit = gone[item.id]
                val targetX = exit ?: if (top) dragX else 0f
                val spec = if (dragging && top) snap<Float>() else tween(280, easing = LinearOutSlowInEasing)
                val x by animateFloatAsState(targetX, spec, label = "x$i")
                val y by animateFloatAsState(if (top) dragY * 0.15f else 0f, spec, label = "y$i")
                val scale by animateFloatAsState(1f - depth * 0.05f, tween(280), label = "s$i")
                val lift by animateFloatAsState(depth * 16f, tween(280), label = "d$i")
                val rot by animateFloatAsState(if (depth == 0) x / 22f else if (depth == 1) 2.5f else -2.5f,
                    if (dragging && top) snap() else tween(280), label = "r$i")
                val alpha by animateFloatAsState(if (exit == null) 1f else 0f, tween(280), label = "a$i")
                val shape = RoundedCornerShape(24.dp)
                Box(
                    Modifier.fillMaxSize()
                        .zIndex((cards.size - i).toFloat())
                        .graphicsLayer {
                            translationX = x * density
                            translationY = (lift + y) * density
                            rotationZ = rot
                            scaleX = scale; scaleY = scale
                            this.alpha = alpha
                        }
                        .then(if (top) Modifier.pointerInput(index) {
                            detectDragGestures(
                                onDragStart = { dragging = true },
                                onDragEnd = {
                                    when {
                                        dragX > 90 -> answer(true)
                                        dragX < -90 -> answer(false)
                                        else -> { dragging = false; dragX = 0f; dragY = 0f }
                                    }
                                },
                                onDragCancel = { dragging = false; dragX = 0f; dragY = 0f },
                            ) { change, amount ->
                                change.consume()
                                dragX += amount.x / density
                                dragY += amount.y / density
                                val nowArmed = abs(dragX) > 90
                                if (nowArmed != armed) { armed = nowArmed; Haptics.selection() }
                            }
                        } else Modifier)
                        .shadow(12.dp, shape, ambientColor = Palette.blueDark.copy(alpha = 0.16f), spotColor = Palette.blueDark.copy(alpha = 0.16f))
                        .clip(shape)
                        .border(5.dp, Color.White, shape)
                ) {
                    ArtImage(item.image, Modifier.fillMaxSize().clip(shape))
                    Box(Modifier.fillMaxSize().border(5.dp, Color.White, shape))
                    if (item.hard) Box(Modifier.align(Alignment.BottomStart).padding(16.dp)) { TagPill(L("Expert level")) }
                    if (top) {
                        Stamp(L("I know it"), Palette.green, Modifier.align(Alignment.TopStart).padding(16.dp)
                            .graphicsLayer { this.alpha = (dragX / 90f).coerceIn(0f, 1f) })
                        Stamp(L("I don't know"), hexColor(0x2D2C2B), Modifier.align(Alignment.TopEnd).padding(16.dp)
                            .graphicsLayer { this.alpha = (-dragX / 90f).coerceIn(0f, 1f) })
                    }
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            PillButton(L("I don't know"), Modifier.weight(1f), style = PillStyle.Secondary) { answer(false) }
            PillButton(L("I know it"), Modifier.weight(1f)) { answer(true) }
        }
    }
}

@Composable
private fun Stamp(text: String, color: Color, modifier: Modifier) {
    Text(text, style = figtree(18, FontWeight.Bold), color = Color.White,
        modifier = modifier.clip(RoundedCornerShape(12.dp)).background(color).padding(horizontal = 14.dp, vertical = 8.dp))
}

// MARK: - Test result: "Well done, Max!"

@Composable
fun FlashResultScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val cards = FlashCard.all
    val total = cards.size
    val known = user.profile.flashKnown
    val score = cards.count { known.contains(it.id) }
    val firstName = user.profile.firstName?.takeIf { it.isNotEmpty() }
    val headline = if (score == 0) firstName?.let { L("Thanks for being honest, %@.", it) } ?: L("Thanks for being honest.")
    else firstName?.let { L("Well done, %@!", it) } ?: L("Well done!")
    val verdict = when (score) {
        total -> L("You know them all, even the hardest ones. But do you know the stories they tell?")
        0 -> L("None yet. That's exactly why we're here.")
        else -> L("The others still escape you. Not for long.")
    }

    var count by remember { mutableIntStateOf(0) }
    var fanned by remember { mutableStateOf(false) }
    var verdictShown by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        launch { delay(500); fanned = true }
        // The counter goes up one notch at a time, with a tick.
        for (i in 1..score) {
            launch {
                delay((900 + i * 220).toLong())
                count = i
                Haptics.rigid()
            }
        }
        launch {
            delay((1200 + score * 220).toLong())
            verdictShown = true
            if (score == 0) Haptics.soft()
        }
    }

    OnbScaffold(title = headline, spoken = true, onNext = onNext) {
        // The seven paintings fanned out: the named ones in color, the others dimmed.
        val fan by animateFloatAsState(if (fanned) 1f else 0f, Anim.settle(), label = "fan")
        BoxWithConstraints(Modifier.fillMaxWidth().height(176.dp).enter(2.0), contentAlignment = Alignment.Center) {
            val step = 78 - 36
            val width = 78 + step * (cards.size - 1)
            cards.forEachIndexed { i, item ->
                val isKnown = known.contains(item.id)
                val spread = i - (cards.size - 1) / 2f
                val shape = RoundedCornerShape(12.dp)
                Box(
                    Modifier
                        .zIndex(if (isKnown) 2f else 1f)
                        .offset(x = (i * step - width / 2 + 39).dp)
                        .graphicsLayer {
                            rotationZ = spread * 6 * fan
                            translationY = abs(spread) * 8 * fan * density
                        }
                        .size(78.dp, 108.dp + 12.dp),
                ) {
                    Box(
                        Modifier.size(78.dp, 108.dp)
                            .shadow(8.dp, shape, ambientColor = Palette.blueDark.copy(alpha = 0.16f), spotColor = Palette.blueDark.copy(alpha = 0.16f))
                            .clip(shape)
                    ) {
                        ArtImage(item.image, Modifier.fillMaxSize().saturation(if (isKnown) 1f else 0f)
                            .graphicsLayer { alpha = if (isKnown) 1f else 0.55f })
                        Box(Modifier.fillMaxSize().border(3.dp, Color.White, shape))
                    }
                    Box(
                        Modifier.align(Alignment.BottomCenter).offset(y = (-2).dp).size(24.dp).clip(CircleShape)
                            .background(if (isKnown) Palette.green else Palette.ink),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(if (isKnown) Icons.Rounded.Check else Icons.Rounded.QuestionMark, null, tint = if (isKnown) Color.White else Palette.bg, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }

        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("$count", style = figtree(72, FontWeight.Bold), color = Palette.blue, modifier = Modifier.alignByBaseline())
                // Shown after the big score number: "5 of 7", then "paintings named" below.
                Text(L("of %@", "$total"), style = figtree(28, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.alignByBaseline())
            }
            Text(if (score == 1) L("painting named") else L("paintings named"), style = figtree(15, FontWeight.SemiBold), color = Palette.muted)
            Text(verdict, style = AType.body, color = Palette.ink, textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp).reveal(verdictShown, 10f))
        }
    }
}

// MARK: - What screen time adds up to, and what it can become

@Composable
fun PhoneResultScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val hours = user.profile.phoneHours
    val target = Math.round(hours * 365 / 24).toDouble()
    val countDuration = 2000
    val months = target / 30.4
    val monthsLine = if (months < 1.25) L("More than a full month, non-stop.")
    else L("Nearly %@ full months, non-stop.", "${months.roundToInt()}")

    /** Days shown: animated from 0 to the total, in a single motion. */
    val days = remember { Animatable(0f) }
    var stage by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        launch { delay(350); stage = 1 }
        launch {
            delay(800)
            // A single continuous motion: fast at the start, very gentle at the end.
            launch { days.animateTo(target.toFloat(), tween(countDuration, easing = countEasing)) }
            var beats = 0
            while (beats * 90 < countDuration * 0.7) { delay(90); beats++; Haptics.whisper() }
        }
        launch { delay((800 + countDuration * 0.8).toLong()); Haptics.heavy(); stage = 2 }
        launch { delay((800 + countDuration + 500).toLong()); stage = 3; Haptics.soft() }
        launch { delay((800 + countDuration + 1300).toLong()); stage = 4 }
    }

    Column(
        Modifier.fillMaxSize().background(Palette.bg)
            .tapAnywhere { if (stage >= 4) { Haptics.tap(); onNext() } }
            .padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f).heightIn(min = 4.dp))
        Column(Modifier.reveal(stage >= 1, 14f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // "4h a day, over a year, adds up to", followed below by a big number and "days".
            Text(L("%@ a day, over a year, adds up to", formatHours(hours)), style = figtree(18, FontWeight.Medium),
                color = Palette.muted, textAlign = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("${days.value.roundToInt()}", style = figtree(104, FontWeight.Bold), color = Palette.ink, modifier = Modifier.alignByBaseline())
                Text(L("days"), style = figtree(32, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.alignByBaseline())
            }
        }
        val barAlpha by animateFloatAsState(if (stage >= 1) 1f else 0f, Anim.settle(), label = "bar")
        YearBar((days.value / 365f).coerceIn(0f, 1f), Modifier.padding(top = 6.dp).graphicsLayer { alpha = barAlpha })
        Text(monthsLine, style = figtree(17, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 14.dp).reveal(stage >= 2, 10f))
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))

        // The turnaround: the Mona Lisa offers something else.
        MascotBubble(84.dp, Modifier.reveal(stage >= 3, 26f)) {
            Text(L("With me, that time can turn into knowledge."), style = figtree(21, FontWeight.SemiBold), color = Palette.ink,
                textAlign = TextAlign.Center)
            Spacer(Modifier.height(6.dp))
            Text(L("Five minutes a day is enough. Instead of doomscrolling, feed your mind with humanity's greatest works."),
                style = figtree(15), color = Palette.muted, textAlign = TextAlign.Center)
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))

        // No button: a tap anywhere moves on, once everything has appeared.
        val hint by animateFloatAsState(if (stage >= 4) 1f else 0f, Anim.gentle(), label = "hint")
        TapHint(Modifier.graphicsLayer { alpha = hint })
    }
}

/** The year in twelve months: the share spent on the phone fills in with the counter. */
@Composable
private fun YearBar(fraction: Float, modifier: Modifier = Modifier) {
    // "J", "F", "M"… in the app's language.
    val initials = remember { Month.entries.map { it.getDisplayName(TextStyle.NARROW_STANDALONE, AppLanguage.locale) } }
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(Modifier.fillMaxWidth().height(22.dp)) {
            val gap = 4.dp.toPx()
            val w = (size.width - gap * 11) / 12
            val r = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx())
            val brush = Brush.horizontalGradient(listOf(Palette.yellow, Palette.orange), 0f, size.width * fraction.coerceAtLeast(0.001f))
            for (i in 0 until 12) {
                val left = i * (w + gap)
                drawRoundRect(Palette.line, Offset(left, 0f), Size(w, size.height), r)
                clipRect(0f, 0f, size.width * fraction, size.height) {
                    drawRoundRect(brush, Offset(left, 0f), Size(w, size.height), r)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            initials.forEach {
                Text(it, style = figtree(11, FontWeight.Medium), color = Palette.muted, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
        }
    }
}

// MARK: - In a year: nearly 400 paintings and artists

@Composable
fun ProjectionScreen(onNext: () -> Unit) {
    val target = 400f
    val countDuration = 2400
    val value = remember { Animatable(0f) }
    var shown by remember { mutableIntStateOf(0) }
    var detailShown by remember { mutableStateOf(false) }
    /** True once the count and the detail line are in: the tap then moves on. */
    var done by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        launch { delay(600); value.animateTo(target, tween(countDuration, easing = countEasing)) }
        for (i in 1..floatingSpaceCount) {
            launch {
                delay((500 + i * 140).toLong())
                shown = maxOf(shown, i)
                Haptics.whisper()
            }
        }
        launch { delay((600 + countDuration * 0.85).toLong()); Haptics.heavy(); detailShown = true }
        launch { delay((600 + countDuration + 400).toLong()); done = true }
    }

    Column(
        Modifier.fillMaxSize().background(Palette.bg)
            .tapAnywhere { if (done) { Haptics.tap(); onNext() } }
            .padding(top = 4.dp, bottom = 16.dp),
    ) {
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            // The paintings come in one by one and float around the number.
            FloatingSpace(shown = shown)
            Column(
                Modifier
                    // A halo in the background color keeps the text readable in front of the paintings.
                    .background(Brush.radialGradient(
                        0f to Palette.bg, 0.4f to Palette.bg, 0.62f to Palette.bg.copy(alpha = 0.94f), 1f to Palette.bg.copy(alpha = 0f),
                        radius = 250f * 2.75f,
                    ))
                    .padding(horizontal = 44.dp, vertical = 36.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // Followed below by a big counting number (400), then "paintings and artists".
                Text(L("With Artura, in one year, you'll know nearly"), style = figtree(20, FontWeight.SemiBold), color = Palette.ink,
                    textAlign = TextAlign.Center, modifier = Modifier.enter())
                Text("${value.value.roundToInt()}", style = figtree(112, FontWeight.Bold), color = Palette.blue)
                Text(L("paintings and artists"), style = figtree(28, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
                Text(L("And not just their names: their stories, in detail."), style = figtree(16), color = Palette.muted,
                    textAlign = TextAlign.Center, modifier = Modifier.padding(top = 10.dp).reveal(detailShown, 10f))
            }
        }
        // No button: a tap anywhere moves on, once the count is over.
        val hint by animateFloatAsState(if (done) 1f else 0f, Anim.gentle(), label = "hint")
        TapHint(Modifier.graphicsLayer { alpha = hint })
    }
}

// MARK: - A few minutes a day changes everything (chart)

private const val startLift = 0.06f

/** Progress curve in `rect`: starts at the bottom left and rises to `lift` (fraction of the height) on the right. */
private fun growthCurve(rect: Rect, lift: Float, closed: Boolean = false): Path {
    fun y(l: Float) = rect.bottom - rect.height * l
    val start = Offset(rect.left, y(startLift))
    val end = Offset(rect.right, y(lift))
    return Path().apply {
        moveTo(start.x, start.y)
        cubicTo(rect.left + rect.width * 0.45f, start.y, rect.left + rect.width * 0.7f, end.y + (start.y - end.y) * 0.3f, end.x, end.y)
        if (closed) {
            lineTo(rect.right, rect.bottom)
            lineTo(rect.left, rect.bottom)
            close()
        }
    }
}

@Composable
fun GrowthChart(modifier: Modifier = Modifier) {
    var drawn by remember { mutableStateOf(false) }
    var ended by remember { mutableStateOf(false) }
    val withLift = 0.94f
    val withoutLift = 0.2f
    val inset = 10.dp

    LaunchedEffect(Unit) {
        launch { delay(600); drawn = true }
        launch { delay(2100); ended = true; Haptics.rigid() }
    }
    val trim by animateFloatAsState(if (drawn) 1f else 0f, tween(1500, easing = FastOutSlowInEasing), label = "trim")
    val end by animateFloatAsState(if (ended) 1f else 0f, Anim.settle(), label = "end")

    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Palette.card).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Canvas(Modifier.fillMaxWidth().height(122.dp)) {
            val i = inset.toPx()
            val rect = Rect(i, i, size.width - i, size.height - i)
            // Guide lines
            for (k in 0 until 4) {
                val y = rect.top + rect.height * k / 3
                val h = if (k == 3) 2.dp.toPx() else 1.dp.toPx()
                drawRect(if (k == 3) Palette.lip else Palette.line, Offset(rect.left, y - h / 2), Size(rect.width, h))
            }
            drawPath(growthCurve(rect, withLift, closed = true),
                Brush.verticalGradient(listOf(Palette.yellow.copy(alpha = 0.34f), Palette.yellow.copy(alpha = 0f)), rect.top, rect.bottom),
                alpha = end)
            fun trimmed(path: Path): Path {
                val m = PathMeasure().apply { setPath(path, false) }
                return Path().also { m.getSegment(0f, m.length * trim, it, true) }
            }
            if (trim > 0f) {
                drawPath(trimmed(growthCurve(rect, withoutLift)), Palette.yellow,
                    style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 7.dp.toPx()))))
                drawPath(trimmed(growthCurve(rect, withLift)), Palette.blue, style = Stroke(4.dp.toPx(), cap = StrokeCap.Round))
            }
            fun dot(color: Color, at: Offset, s: Float, a: Float) {
                val r = 8.dp.toPx() * s
                drawCircle(Color.White.copy(alpha = a), r, at)
                drawCircle(color.copy(alpha = color.alpha * a), r - 2.dp.toPx() * s, at, style = Stroke(4.dp.toPx() * s))
            }
            fun y(l: Float) = rect.bottom - rect.height * l
            dot(Palette.blue, Offset(rect.left, y(startLift)), 1f, 1f)
            dot(Palette.yellow, Offset(rect.right, y(withoutLift)), 0.3f + 0.7f * end, end)
            dot(Palette.blue, Offset(rect.right, y(withLift)), 0.3f + 0.7f * end, end)
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = inset)) {
            Text(L("Today"), style = AType.small, color = Palette.muted)
            Spacer(Modifier.weight(1f))
            Text(L("In 1 year"), style = figtree(14, FontWeight.SemiBold), color = Palette.ink)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically) {
            Legend(L("With Artura"), Palette.blue, dashed = false)
            Legend(L("No routine"), Palette.yellow, dashed = true)
        }
    }
}

@Composable
private fun Legend(text: String, color: Color, dashed: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            repeat(if (dashed) 3 else 1) {
                Box(Modifier.width(if (dashed) 6.dp else 24.dp).height(4.dp).clip(CircleShape).background(color))
            }
        }
        Text(text, style = AType.small, color = Palette.ink)
    }
}

@Composable
fun GraphScreen(onNext: () -> Unit) {
    // Each line completes "With Artura, you develop…".
    val gains = listOf(L("your eye for art"), L("your general knowledge"), L("your conversation topics"))
    OnbScaffold(title = L("A few minutes a day changes everything."), spoken = true, mascotSize = 84.dp, onNext = onNext) {
        GrowthChart(Modifier.enter(2.0))
        Column(Modifier.fillMaxWidth().enter(4.0).clip(RoundedCornerShape(22.dp)).background(Palette.card)
            .padding(horizontal = 18.dp, vertical = 12.dp)) {
            Text(L("With Artura, you develop"), style = figtree(19, FontWeight.SemiBold), color = Palette.ink,
                modifier = Modifier.padding(bottom = 6.dp))
            gains.forEachIndexed { i, gain ->
                Row(Modifier.fillMaxWidth().height(30.dp).enter(i * 2.0 + 16), verticalAlignment = Alignment.CenterVertically) {
                    Text(gain, style = AType.body, color = Palette.ink, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Rounded.TrendingUp, null, tint = Palette.orange, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

// MARK: - Streak: "Max, your learning starts today"

@Composable
fun StreakScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val name = user.profile.firstName
    val title = if (!name.isNullOrEmpty()) L("%@, your learning starts today.", name) else L("Your learning starts today.")
    var lit by remember { mutableStateOf(false) }
    var checked by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        launch { delay(500); lit = true }
        launch { delay(1100); checked = true; Haptics.success() }
    }
    val l by animateFloatAsState(if (lit) 1f else 0f, Anim.settle(), label = "lit")
    val c by animateFloatAsState(if (checked) 1f else 0f, tween(250), label = "check")

    Column(
        Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.fillMaxWidth().weight(1f, fill = false).heightIn(min = 176.dp, max = 276.dp).enter()) {
            ArtImage("ill_serie", Modifier.padding(bottom = 26.dp).fillMaxWidth().heightIn(min = 150.dp, max = 250.dp).clip(RoundedCornerShape(28.dp)),
                zoom = 1f + 0.06f * l, anchor = Offset(0.5f, 0.6f))
            // The first-day flame, straddling the bottom of the image.
            Row(
                Modifier.align(Alignment.BottomCenter).offset(y = 0.dp)
                    .graphicsLayer { val s = 0.6f + 0.4f * l; scaleX = s; scaleY = s; alpha = l }
                    .height(52.dp)
                    .shadow(12.dp, CircleShape, ambientColor = Palette.blueDark.copy(alpha = 0.14f), spotColor = Palette.blueDark.copy(alpha = 0.14f))
                    .background(Palette.bg, CircleShape).padding(horizontal = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Rounded.LocalFireDepartment, null, tint = Palette.orange, modifier = Modifier.size(26.dp))
                Text(L("Day 1"), style = figtree(22, FontWeight.Bold), color = Palette.ink)
            }
        }
        Column(Modifier.padding(top = 22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = AType.title, color = Palette.ink, textAlign = TextAlign.Center, modifier = Modifier.enter(3.0))
            Text(L("Come back tomorrow to grow your streak."), style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center,
                modifier = Modifier.enter(4.5))
        }
        // The week: the first day gets checked.
        Row(
            Modifier.padding(top = 22.dp).enter(6.0).fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Palette.card)
                .padding(horizontal = 12.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            for (day in 1..7) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    val on = day == 1 && checked
                    Box(
                        Modifier.size(34.dp).clip(CircleShape).background(if (on) Palette.yellow else Palette.bg)
                            .border(1.5.dp, if (on) Palette.yellow else Palette.lip, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (day == 1) Icon(Icons.Rounded.Check, null, tint = hexColor(0x2D2C2B),
                            modifier = Modifier.size(18.dp).graphicsLayer { scaleX = c; scaleY = c; alpha = c })
                    }
                    // Short for "Day 1", "Day 2"… under each circle of the week (keep it very short).
                    Text(L("D%@", "$day"), style = figtree(12, if (day == 1) FontWeight.Bold else FontWeight.Normal),
                        color = if (day == 1) Palette.ink else Palette.muted)
                }
            }
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        PillButton(L("Continue")) { onNext() }
    }
}
