package com.vikstudios.artura.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArcHeaderShape
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.TextLinkButton
import com.vikstudios.artura.core.drawableId
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

// Building blocks shared by all onboarding screens: staggered entrances, character, speech bubble,
// typed text, wall of paintings, rays, answer rows, screen templates (port of OnboardingKit.swift and
// the templates at the end of OnboardingFlow.swift).

// MARK: - Staggered entrance

/** Brings the element in when its turn comes: 0 for the first, 1 for the next, and so on. */
fun Modifier.enter(order: Double = 0.0): Modifier = composed {
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(((0.1 + order * 0.09) * 1000).toLong())
        shown = true
    }
    val t by animateFloatAsState(if (shown) 1f else 0f, Anim.settle(), label = "enter")
    Modifier.graphicsLayer { alpha = t; translationY = (1 - t) * 18.dp.toPx() }
}

// MARK: - Featured numbers

/** Numbers shown in the onboarding. To be replaced with the real ones (users, store rating) before release. */
object SocialProof {
    const val learners = "100,000"
    const val rating = "4.8"
    /** Sample reviews: to be replaced with real reviews. */
    val reviews: List<String>
        get() = listOf(
            L("Five minutes in the morning, and I finally see paintings differently."),
            L("The mini-games really help me remember names and dates."),
            L("I knew nothing about art. Now I look forward to the notification."),
        )
}

// MARK: - The character: the Mona Lisa

/** The Mona Lisa from the app icon, who guides the onboarding. She floats gently. */
@Composable
fun Mascot(size: Dp = 132.dp, modifier: Modifier = Modifier) {
    val float by rememberInfiniteTransition(label = "mascot").animateFloat(
        -3f, 3f, infiniteRepeatable(tween(2400), RepeatMode.Reverse), label = "float")
    Image(
        painterResource(drawableId("joconde")), null, contentScale = ContentScale.Fit,
        modifier = modifier.size(size).graphicsLayer { translationY = -float * density },
    )
}

/** Speech bubble: a rounded rectangle with a tail pointing up, in the center. */
class BubbleShape(private val radius: Dp = 26.dp, private val tail: Dp = 12.dp) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val t = with(density) { tail.toPx() }
        val r = with(density) { radius.toPx() }
        val p = Path().apply {
            addRoundRect(RoundRect(0f, t, size.width, size.height, CornerRadius(r, r)))
            moveTo(size.width / 2 - t * 1.1f, t + 1)
            lineTo(size.width / 2, 0f)
            lineTo(size.width / 2 + t * 1.1f, t + 1)
            close()
        }
        return Outline.Generic(p)
    }
}

/** The Mona Lisa above a bubble: what she "says" is the content. */
@Composable
fun MascotBubble(mascotSize: Dp = 132.dp, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    // The bottom of the bust goes behind the bubble.
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Mascot(mascotSize)
        Column(
            Modifier
                .offset(y = (-14).dp)
                .fillMaxWidth()
                .shadow(18.dp, BubbleShape(), ambientColor = Palette.blueDark.copy(alpha = 0.10f), spotColor = Palette.blueDark.copy(alpha = 0.18f))
                .background(Color.White, BubbleShape())
                .padding(start = 22.dp, end = 22.dp, top = 34.dp, bottom = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            content = content,
        )
    }
}

// MARK: - The Mona Lisa speaks: typed text, one line after another

/**
 * Dialogue screen: the Mona Lisa says one or more lines, typed letter by letter at a steady pace.
 * A tap while typing shows the whole line; the next tap moves on.
 */
@Composable
fun MascotTalkScreen(
    lines: List<String>,
    onNext: () -> Unit,
    cta: String = L("Continue"),
    mascotSize: Dp = 156.dp,
    extra: (@Composable () -> Unit)? = null,
) {
    var index by remember { mutableIntStateOf(OnboardingDebug.int("onbLine").coerceIn(0, 9)) }
    /** Seconds since the current line started to appear. */
    var elapsed by remember { mutableDoubleStateOf(0.0) }
    var typing by remember { mutableStateOf(true) }
    val fade = 0.05
    val line = lines[minOf(index, lines.size - 1)]
    val isLast = index >= lines.size - 1

    fun schedule(characters: String): List<Double> {
        val times = ArrayList<Double>(characters.length)
        var t = 0.0
        for (c in characters) {
            times.add(t)
            t += when (c) { '.', ':', '!', '?' -> 0.20; ',' -> 0.10; else -> 0.03 }
        }
        return times
    }

    LaunchedEffect(index) {
        val times = schedule(line)
        val total = (times.lastOrNull() ?: 0.0) + fade
        typing = true
        elapsed = 0.0
        delay(450)
        val start = System.nanoTime()
        var ticks = 0
        while (typing) {
            val now = (System.nanoTime() - start) / 1e9
            if (now >= total) break
            elapsed = now
            // A light tick every few letters.
            val reached = times.count { it <= now }
            if (reached / 4 > ticks) { ticks = reached / 4; Haptics.whisper() }
            withFrameMillis { }
        }
        if (typing) Haptics.soft()
        elapsed = Double.MAX_VALUE
        typing = false
    }

    fun advance() {
        when {
            typing -> { typing = false; elapsed = Double.MAX_VALUE; Haptics.tap() }
            !isLast -> { elapsed = 0.0; typing = true; index++ }
            else -> onNext()
        }
    }

    Column(
        Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
        MascotBubble(mascotSize, Modifier.enter()) {
            // Room for the whole line is reserved from the start: the bubble doesn't move while the text appears.
            val times = remember(line) { schedule(line) }
            val text = buildAnnotatedString {
                line.forEachIndexed { i, c ->
                    val a = when {
                        elapsed >= times[i] + fade -> 1f
                        elapsed > times[i] -> ((elapsed - times[i]) / fade).toFloat().coerceIn(0f, 1f)
                        else -> 0f
                    }
                    withStyle(SpanStyle(color = Palette.ink.copy(alpha = a))) { append(c) }
                }
            }
            Text(text, style = figtree(24, FontWeight.SemiBold).copy(lineHeight = 33.sp), textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth())
        }
        if (lines.size > 1) {
            // Where we are in the conversation
            Row(Modifier.padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                lines.indices.forEach { i ->
                    val w by animateDpAsState(if (i == index) 18.dp else 6.dp, Anim.gentle(), label = "dot")
                    Box(Modifier.size(w, 6.dp).clip(CircleShape).background(if (i <= index) Palette.blue else Palette.lip))
                }
            }
        }
        AnimatedVisibility(isLast && extra != null, enter = fadeIn() + slideInVertically { 30 }) {
            Box(Modifier.padding(top = 18.dp)) { extra?.invoke() }
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        PillButton(if (isLast) cta else L("Continue")) { advance() }
    }
}

// MARK: - Counting number

/** Whole number that counts up or down smoothly when its value changes. */
@Composable
fun CountingText(value: Double, suffix: String = "", style: androidx.compose.ui.text.TextStyle, color: Color, durationMs: Int = 600) {
    val v by animateFloatAsState(value.toFloat(), tween(durationMs), label = "count")
    Text("${Math.round(v)}$suffix", style = style, color = color)
}

// MARK: - Time, for continuous animations

/** Seconds since the screen appeared, updated every frame (SwiftUI `TimelineView(.animation)`). */
@Composable
fun rememberClock(): Double {
    var t by remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { t = (it - start) / 1000.0 }
    }
    return t
}

// MARK: - Paintings floating in space

private data class FloatItem(val image: String, val x: Float, val y: Float, val size: Float, val depth: Double)

private val floatItems = listOf(
    FloatItem("wall_venus", 0.12f, 0.07f, 66f, 1.0),
    FloatItem("art_nuit", 0.84f, 0.06f, 72f, 1.0),
    FloatItem("wall_cri", 0.48f, 0.03f, 50f, 0.6),
    FloatItem("art_perle", 0.94f, 0.27f, 56f, 0.75),
    FloatItem("wall_laitiere", 0.05f, 0.29f, 58f, 0.8),
    FloatItem("wall_menines", 0.90f, 0.50f, 60f, 0.9),
    FloatItem("art_vague", 0.08f, 0.53f, 52f, 0.65),
    FloatItem("wall_cafe", 0.16f, 0.77f, 68f, 1.0),
    FloatItem("art_baiser", 0.84f, 0.74f, 66f, 0.95),
    FloatItem("wall_amandier", 0.50f, 0.86f, 54f, 0.7),
    FloatItem("wall_grandejatte", 0.30f, 0.95f, 56f, 0.8),
    FloatItem("art_tournesols", 0.70f, 0.96f, 50f, 0.6),
    FloatItem("wall_fuji", 0.95f, 0.92f, 52f, 0.7),
    FloatItem("wall_hermine", 0.03f, 0.93f, 50f, 0.6),
)

/** Number of paintings of `FloatingSpace`. */
val floatingSpaceCount: Int get() = floatItems.size

/** Scattered paintings drifting slowly, as if weightless. Used as a backdrop behind content. */
@Composable
fun FloatingSpace(modifier: Modifier = Modifier, shown: Int = floatItems.size, withSculpture: Boolean = false) {
    val time = rememberClock()
    BoxWithConstraints(modifier.fillMaxSize()) {
        floatItems.forEachIndexed { i, item ->
            val phase = i * 1.37
            val visible = i < shown
            val v by animateFloatAsState(if (visible) 1f else 0f, Anim.settle(), label = "float$i")
            val size = item.size.dp
            val shape = RoundedCornerShape(size * 0.22f)
            val x = maxWidth * item.x + (sin(time * 0.27 + phase) * 9 * item.depth).toFloat().dp - size / 2
            val y = maxHeight * item.y + (cos(time * 0.22 + phase * 1.3) * 12 * item.depth).toFloat().dp - size / 2
            ArtImage(
                if (withSculpture && i == 5) "ill_sculpture" else item.image,
                Modifier
                    .offset(x, y)
                    .size(size)
                    .graphicsLayer {
                        alpha = v * (0.35f + 0.65f * item.depth.toFloat())
                        val s = 0.5f + 0.5f * v
                        scaleX = s; scaleY = s
                        rotationZ = (sin(time * 0.35 + phase) * 6).toFloat()
                    }
                    .clip(shape)
                    .border(3.dp, Color.White, shape),
            )
        }
    }
}

// MARK: - Scrolling wall of paintings

private val wallRows = listOf(
    listOf("art_nuit", "wall_venus", "art_perle", "wall_cri", "wall_amandier", "art_baiser", "wall_menines", "wall_fuji", "art_raboteurs"),
    listOf("wall_laitiere", "art_vague", "wall_cafe", "art_joconde", "wall_grandejatte", "wall_hermine", "art_tournesols", "wall_babel", "wall_danse"),
    listOf("art_impression", "wall_galette", "wall_voyageur", "art_nympheas", "wall_adele", "wall_chambre", "wall_glaneuses", "art_moine", "wall_fifre", "wall_ronde"),
)
/** Speed of each row, in dp per second (negative: to the right). */
private val wallSpeeds = listOf(16.0, -20.0, 13.0)

/** Rows of small square paintings gliding in opposite directions, swaying slightly. */
@Composable
fun FloatingWall(modifier: Modifier = Modifier, tile: Dp = 80.dp, spacing: Dp = 12.dp) {
    val time = rememberClock()
    Column(
        modifier
            .fillMaxWidth()
            // The edges fade out: the paintings come and go smoothly.
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .drawWithContent {
                drawContent()
                drawRect(
                    Brush.horizontalGradient(0f to Color.Transparent, 0.14f to Color.Black, 0.86f to Color.Black, 1f to Color.Transparent),
                    blendMode = BlendMode.DstIn,
                )
            },
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) {
        wallRows.forEachIndexed { row, images ->
            val step = (tile + spacing).value.toDouble()
            val period = step * images.size
            var shift = (time * wallSpeeds[row % wallSpeeds.size]) % period
            if (shift < 0) shift += period
            // The row is laid out twice end to end: the loop is invisible.
            Box(Modifier.fillMaxWidth().height(tile + 14.dp), contentAlignment = Alignment.CenterStart) {
                Row(
                    Modifier.wrapContentWidth(Alignment.Start, unbounded = true).offset(x = (-shift).toFloat().dp),
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                ) {
                    for (i in 0 until images.size * 2) {
                        val wave = (i % images.size) * 0.9 + row * 1.7
                        val shape = RoundedCornerShape(18.dp)
                        ArtImage(
                            images[i % images.size],
                            Modifier
                                .graphicsLayer {
                                    rotationZ = (sin(time * 0.55 + wave) * 2.4).toFloat()
                                    translationY = (sin(time * 0.8 + wave) * 5).toFloat() * density
                                }
                                .size(tile)
                                .clip(shape)
                                .border(3.dp, Color.White, shape),
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Rays and sparkles (gift screens)

/** Rays spreading from the center, like a sun. */
class Sunburst(private val rays: Int = 14) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val c = Offset(size.width / 2, size.height / 2)
        val radius = hypot(size.width, size.height)
        val step = 2 * PI.toFloat() / rays
        val p = Path()
        for (i in 0 until rays) {
            val from = i * step
            val to = from + step * 0.42f
            p.moveTo(c.x, c.y)
            p.lineTo(c.x + cos(from) * radius, c.y + sin(from) * radius)
            p.lineTo(c.x + cos(to) * radius, c.y + sin(to) * radius)
            p.close()
        }
        return Outline.Generic(p)
    }
}

/** Background of golden rays turning very slowly. */
@Composable
fun RaysBackground(modifier: Modifier = Modifier) {
    val spin by rememberInfiniteTransition(label = "rays").animateFloat(
        0f, 360f, infiniteRepeatable(tween(70_000, easing = LinearEasing)), label = "spin")
    Box(
        modifier
            .fillMaxSize()
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .drawWithContent {
                drawContent()
                val r = 520.dp.toPx()
                drawRect(
                    Brush.radialGradient(
                        0f to Color.Black, (40.dp.toPx() / r) to Color.Black, 0.55f to Color.Black.copy(alpha = 0.85f), 1f to Color.Transparent,
                        center = center, radius = r,
                    ),
                    blendMode = BlendMode.DstIn,
                )
            }
    ) {
        Box(
            Modifier.requiredWidth(1400.dp).height(1400.dp).align(Alignment.Center).rotate(spin)
                .background(Palette.yellow.copy(alpha = 0.17f), Sunburst())
        )
    }
}

/** Four-pointed sparkle. */
object Sparkle : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val c = Offset(size.width / 2, size.height / 2)
        val r = minOf(size.width, size.height) / 2
        val k = r * 0.2f
        val p = Path().apply {
            moveTo(c.x, c.y - r)
            quadraticTo(c.x + k, c.y - k, c.x + r, c.y)
            quadraticTo(c.x + k, c.y + k, c.x, c.y + r)
            quadraticTo(c.x - k, c.y + k, c.x - r, c.y)
            quadraticTo(c.x - k, c.y - k, c.x, c.y - r)
            close()
        }
        return Outline.Generic(p)
    }
}

// MARK: - Answer row

/**
 * Selectable answer for onboarding questions (single or multiple choice). A plain light card; once chosen,
 * a pale blue card with a blue outline and a check.
 */
@Composable
fun ChoiceRow(
    title: String,
    selected: Boolean,
    subtitle: String? = null,
    /** Name of a small grainy illustration shown at the start of the row. */
    image: String? = null,
    multiple: Boolean = false,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = if (image == null) 64.dp else 66.dp)
            .pressable { Haptics.selection(); onClick() }
            .clip(shape)
            .background(if (selected) Palette.mistLight else Palette.card)
            .border(2.dp, if (selected) Palette.blue else Color.Transparent, shape)
            .padding(start = if (image == null) 18.dp else 10.dp, end = 16.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (image != null) ArtImage(image, Modifier.size(46.dp).clip(RoundedCornerShape(13.dp)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = AType.bodyStrong, color = Palette.ink)
            if (subtitle != null) Text(subtitle, style = AType.caption, color = Palette.muted)
        }
        // Circle for a single choice, rounded square for a multiple choice.
        val corner = if (multiple) 8.dp else 13.dp
        val check by animateFloatAsState(if (selected) 1f else 0f, Anim.snappy(), label = "check")
        Box(
            Modifier.size(26.dp).clip(RoundedCornerShape(corner))
                .background(if (selected) Palette.blue else Color.White)
                .border(2.dp, if (selected) Palette.blue else Palette.lip, RoundedCornerShape(corner)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Check, null, tint = Color.White,
                modifier = Modifier.size(16.dp).graphicsLayer { val s = 0.4f + 0.6f * check; scaleX = s; scaleY = s; alpha = check })
        }
    }
}

// MARK: - Screen templates

/**
 * Template for question screens: title, content, button. The top bar is handled by `OnboardingFlow`.
 * The content scrolls if the screen is too small; the button always stays visible.
 */
@Composable
fun OnbScaffold(
    title: String,
    onNext: () -> Unit,
    subtitle: String? = null,
    /** If true, the Mona Lisa asks the question, in a speech bubble. */
    spoken: Boolean = false,
    mascotSize: Dp = 92.dp,
    cta: String = L("Continue"),
    ctaEnabled: Boolean = true,
    secondaryTitle: String? = null,
    onSecondary: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize().background(Palette.bg), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (spoken) {
                MascotBubble(mascotSize, Modifier.enter()) {
                    Text(title, style = figtree(23, FontWeight.SemiBold), color = Palette.ink, textAlign = TextAlign.Center)
                    if (subtitle != null) {
                        Spacer(Modifier.height(6.dp))
                        Text(subtitle, style = figtree(15), color = Palette.muted, textAlign = TextAlign.Center)
                    }
                }
            } else {
                Column(Modifier.fillMaxWidth().enter(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(title, style = AType.title, color = Palette.ink)
                    if (subtitle != null) Text(subtitle, style = AType.body, color = Palette.muted)
                }
            }
            content()
        }
        Column(
            Modifier.padding(horizontal = 24.dp).padding(bottom = if (secondaryTitle == null) 16.dp else 4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            val a by animateFloatAsState(if (ctaEnabled) 1f else 0.4f, Anim.snappy(), label = "cta")
            PillButton(cta, Modifier.graphicsLayer { alpha = a }, enabled = ctaEnabled) { onNext() }
            if (secondaryTitle != null && onSecondary != null) TextLinkButton(secondaryTitle, onClick = onSecondary)
        }
    }
}

/** Slow back-and-forth zoom of an illustration ("breathes" while you read). */
@Composable
private fun breathing(to: Float, durationMs: Int): Float {
    val v by rememberInfiniteTransition(label = "breath").animateFloat(
        1f, to, infiniteRepeatable(tween(durationMs), RepeatMode.Reverse), label = "zoom")
    return v
}

/** Template for "story" screens: an illustration, a strong line, a button. */
@Composable
fun StoryScaffold(
    image: String,
    title: String,
    onNext: () -> Unit,
    tag: String? = null,
    subtitle: String? = null,
    cta: String = L("Continue"),
) {
    val zoom = breathing(1.09f, 7000)
    Column(
        Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ArtImage(image, Modifier.fillMaxWidth().weight(1f, fill = false).heightIn(min = 180.dp, max = 330.dp)
            .enter().clip(RoundedCornerShape(28.dp)), zoom = zoom)
        Column(Modifier.padding(top = 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (tag != null) Box(Modifier.enter(1.0)) { TagPill(tag) }
            Text(title, style = AType.title, color = Palette.ink, textAlign = TextAlign.Center, modifier = Modifier.enter(2.0))
            if (subtitle != null) Text(subtitle, style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center, modifier = Modifier.enter(3.5))
        }
        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))
        PillButton(cta) { onNext() }
    }
}

/** Template for screens with a large edge-to-edge illustration at the top. */
@Composable
fun HeroScaffold(
    image: String,
    onNext: () -> Unit,
    imageHeight: Dp = 410.dp,
    cta: String = L("Continue"),
    secondaryTitle: String? = null,
    onSecondary: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val zoom = breathing(1.07f, 8000)
    Column(Modifier.fillMaxSize().background(Palette.bg), horizontalAlignment = Alignment.CenterHorizontally) {
        ArtImage(image, Modifier.fillMaxWidth().height(imageHeight).clip(ArcHeaderShape), zoom = zoom)
        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-28).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
            content = content,
        )
        Spacer(Modifier.weight(1f).heightIn(min = 12.dp))
        Column(
            Modifier.padding(horizontal = 24.dp).padding(bottom = if (secondaryTitle == null) 16.dp else 4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            PillButton(cta) { onNext() }
            if (secondaryTitle != null && onSecondary != null) TextLinkButton(secondaryTitle, onClick = onSecondary)
        }
    }
}
