package com.vikstudios.artura.onboarding

import android.app.Activity
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.app.LocalPro
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArcHeaderShape
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.TextLinkButton
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.drawableId
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.services.Analytics
import com.vikstudios.artura.services.ProStore
import com.vikstudios.artura.services.Reminder
import com.vikstudios.artura.services.TrialOffer
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.math.BigDecimal
import java.math.RoundingMode
import kotlin.math.roundToInt

// Port of OnboardingPaywall.swift. End of the onboarding: the surprise, the gift (free trial),
// "no commitment", how the trial works, then the last-minute offer when leaving.

object Legal {
    /** Terms of use: the standard agreement used by the iOS app, to be replaced if the app has its own. */
    const val terms: String = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    /** Privacy policy: to be filled in before release. */
    val privacy: String? = null
}

private fun dayCountWord(days: Int): String = when (days) {
    // L: number word starting the sentence "%@ days, everything unlocked."
    3 -> L("Three")
    7 -> L("Seven")
    14 -> L("Fourteen")
    else -> "$days"
}

// MARK: - Isometric drawing (gift box)

/**
 * Projects a point (x, y, z) of a unit cube onto the screen, in isometric view.
 * The corner closest to the viewer, (1, 1, 0), lands at the bottom center of the frame.
 */
private class Iso(val size: Size) {
    val unit = size.width / 1.732f
    fun point(x: Float, y: Float, z: Float) =
        Offset(size.width / 2 + (x - y) * 0.866f * unit, size.height - unit + (x + y) * 0.5f * unit - z * unit)
}

private val giftOutline = hexColor(0x0A1830)
private val ribbon = Palette.yellow
private val ribbonShade = hexColor(0xD98E00)

private fun isoPath(iso: Iso, corners: List<List<Float>>) = Path().apply {
    corners.forEachIndexed { i, c ->
        val p = iso.point(c[0], c[1], c[2])
        if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
    }
    close()
}

private fun DrawScope.face(iso: Iso, corners: List<List<Float>>, color: Color) {
    val p = isoPath(iso, corners)
    drawPath(p, color)
    drawPath(p, giftOutline, style = Stroke(2.dp.toPx(), join = StrokeJoin.Round))
}

private fun DrawScope.bow(iso: Iso, height: Float) {
    val c = iso.point(0.5f, 0.5f, height)
    val k = density
    val p = Path().apply {
        // Two loops
        moveTo(c.x, c.y)
        cubicTo(c.x - 58 * k, c.y - 44 * k, c.x - 64 * k, c.y + 4 * k, c.x, c.y)
        moveTo(c.x, c.y)
        cubicTo(c.x + 58 * k, c.y - 44 * k, c.x + 64 * k, c.y + 4 * k, c.x, c.y)
        // Two tails
        moveTo(c.x, c.y); lineTo(c.x - 20 * k, c.y + 26 * k); lineTo(c.x - 6 * k, c.y + 20 * k); close()
        moveTo(c.x, c.y); lineTo(c.x + 20 * k, c.y + 26 * k); lineTo(c.x + 6 * k, c.y + 20 * k); close()
        addOval(Rect(c.x - 9 * k, c.y - 8 * k, c.x + 9 * k, c.y + 8 * k))
    }
    drawPath(p, hexColor(0xFFCB52))
    drawPath(p, giftOutline, style = Stroke(2.dp.toPx(), join = StrokeJoin.Round))
}

/** Gift box in isometric view. Closed, it waits; opened, the lid lifts and light pours out. */
@Composable
fun GiftBox(opened: Boolean, modifier: Modifier = Modifier) {
    val h = 0.82f
    val t = 0.2f
    val m = 0.07f
    val o by animateFloatAsState(if (opened) 1f else 0f, Anim.settle(), label = "open")
    Box(modifier.size(190.dp, 200.dp), contentAlignment = Alignment.Center) {
        // Ground shadow
        Canvas(Modifier.size(190.dp, 200.dp).blur(10.dp, androidx.compose.ui.draw.BlurredEdgeTreatment.Unbounded)) {
            val iso = Iso(size)
            drawPath(isoPath(iso, listOf(listOf(-0.14f, -0.14f, 0f), listOf(1.14f, -0.14f, 0f), listOf(1.14f, 1.14f, 0f), listOf(-0.14f, 1.14f, 0f))),
                Palette.blueDark.copy(alpha = 0.16f))
        }
        // The body of the box
        Canvas(Modifier.size(190.dp, 200.dp)) {
            val iso = Iso(size)
            face(iso, listOf(listOf(0f, 0f, h), listOf(1f, 0f, h), listOf(1f, 1f, h), listOf(0f, 1f, h)), giftOutline)
            face(iso, listOf(listOf(0f, 1f, 0f), listOf(1f, 1f, 0f), listOf(1f, 1f, h), listOf(0f, 1f, h)), Palette.blue)
            face(iso, listOf(listOf(1f, 1f, 0f), listOf(1f, 0f, 0f), listOf(1f, 0f, h), listOf(1f, 1f, h)), hexColor(0x132744))
            face(iso, listOf(listOf(0.4f, 1f, 0f), listOf(0.6f, 1f, 0f), listOf(0.6f, 1f, h), listOf(0.4f, 1f, h)), ribbon)
            face(iso, listOf(listOf(1f, 0.6f, 0f), listOf(1f, 0.4f, 0f), listOf(1f, 0.4f, h), listOf(1f, 0.6f, h)), ribbonShade)
        }
        // The light coming out of the box
        Canvas(Modifier.size(160.dp, 120.dp).offset(y = (-48).dp).graphicsLayer { alpha = o }) {
            drawOval(Brush.radialGradient(
                0f to hexColor(0xFFE9B0), 0.5f to Palette.yellow.copy(alpha = 0.55f), 1f to Palette.yellow.copy(alpha = 0f),
                center = center, radius = 78.dp.toPx()))
        }
        // The lid
        Canvas(Modifier.size(190.dp, 200.dp).graphicsLayer {
            translationX = 8.dp.toPx() * o
            translationY = -86.dp.toPx() * o
            rotationZ = -11f * o
        }) {
            val iso = Iso(size)
            val top = h + t
            face(iso, listOf(listOf(-m, 1 + m, h), listOf(1 + m, 1 + m, h), listOf(1 + m, 1 + m, top), listOf(-m, 1 + m, top)), hexColor(0x27487A))
            face(iso, listOf(listOf(1 + m, 1 + m, h), listOf(1 + m, -m, h), listOf(1 + m, -m, top), listOf(1 + m, 1 + m, top)), hexColor(0x1A3560))
            face(iso, listOf(listOf(-m, -m, top), listOf(1 + m, -m, top), listOf(1 + m, 1 + m, top), listOf(-m, 1 + m, top)), hexColor(0x2F5591))
            face(iso, listOf(listOf(0.4f, 1 + m, h), listOf(0.6f, 1 + m, h), listOf(0.6f, 1 + m, top), listOf(0.4f, 1 + m, top)), ribbon)
            face(iso, listOf(listOf(1 + m, 0.6f, h), listOf(1 + m, 0.4f, h), listOf(1 + m, 0.4f, top), listOf(1 + m, 0.6f, top)), ribbonShade)
            face(iso, listOf(listOf(-m, 0.4f, top), listOf(1 + m, 0.4f, top), listOf(1 + m, 0.6f, top), listOf(-m, 0.6f, top)), ribbon)
            face(iso, listOf(listOf(0.4f, -m, top), listOf(0.6f, -m, top), listOf(0.6f, 1 + m, top), listOf(0.4f, 1 + m, top)), ribbon)
            bow(iso, top)
        }
    }
}

// MARK: - 1 · The surprise, then the gift opening

@Composable
fun GiftScreen(offer: TrialOffer, onNext: () -> Unit) {
    var opened by remember { mutableStateOf(OnboardingDebug.flag("onbGiftOpen")) }
    val scope = rememberCoroutineScope()
    val loops = rememberInfiniteTransition(label = "gift")
    val wobble by loops.animateFloat(-2.2f, 2.2f, infiniteRepeatable(tween(550, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "wobble")
    val twinkle by loops.animateFloat(0.8f, 1.15f, infiniteRepeatable(tween(1300, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "twinkle")
    val o by animateFloatAsState(if (opened) 1f else 0f, Anim.settle(), label = "opened")

    fun open() {
        Haptics.heavy()
        opened = true
        scope.launch {
            for (i in 1..3) { delay(140); Haptics.rigid() }
            delay(230)
            Haptics.success()
        }
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        RaysBackground(Modifier.graphicsLayer { alpha = o })

        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.enter()) {
                if (opened) {
                    Column(
                        Modifier.padding(top = 36.dp).graphicsLayer { alpha = o; translationY = (1 - o) * 14.dp.toPx() },
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(L("Before you start, all of Artura is on us."), style = figtree(32, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center)
                        Text(L("%@ days, everything unlocked. You'll see, it changes everything.", dayCountWord(offer.trialDays)),
                            style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center)
                    }
                } else {
                    MascotBubble(118.dp, Modifier.padding(top = 8.dp)) {
                        Text(L("And the best for last…"), style = AType.titleSmall, color = Palette.ink, textAlign = TextAlign.Center)
                        Spacer(Modifier.height(6.dp))
                        Text(L("I have a surprise for you."), style = figtree(17), color = Palette.muted, textAlign = TextAlign.Center)
                    }
                }
            }

            Spacer(Modifier.weight(1f).heightIn(min = 20.dp))

            Box(Modifier.padding(top = 60.dp).enter(2.0), contentAlignment = Alignment.Center) {
                GiftBox(opened, Modifier.graphicsLayer {
                    rotationZ = if (opened) 0f else wobble
                    transformOrigin = TransformOrigin(0.5f, 1f)
                })
                GiftSparkle(22.dp, -112.dp, -70.dp, 250, opened, twinkle)
                GiftSparkle(16.dp, 104.dp, -96.dp, 400, opened, twinkle)
                GiftSparkle(14.dp, 118.dp, 6.dp, 550, opened, twinkle)
                GiftSparkle(12.dp, -96.dp, 30.dp, 700, opened, twinkle)
            }

            Spacer(Modifier.weight(1f).heightIn(min = 20.dp))

            PillButton(if (opened) L("Claim my gift") else L("Open my surprise")) { if (opened) onNext() else open() }
            Box(Modifier.height(36.dp).graphicsLayer { alpha = o }, contentAlignment = Alignment.Center) {
                Text(L("No commitment. Cancel anytime."), style = AType.small, color = Palette.muted)
            }
        }
    }
}

@Composable
private fun GiftSparkle(size: Dp, x: Dp, y: Dp, delayMs: Int, opened: Boolean, twinkle: Float) {
    val v by animateFloatAsState(if (opened) 1f else 0f, tween(600, delayMillis = delayMs, easing = Anim.glideEasing), label = "sparkle")
    Box(
        Modifier.offset(x, y).size(size)
            .graphicsLayer { val s = 0.1f + (twinkle - 0.1f) * v; scaleX = s; scaleY = s; alpha = v }
            .background(Palette.yellow, Sparkle)
    )
}

// MARK: - 2 · No commitment

/** Trial watch: one slice per day, the last one in green. The hand stops the day before the end. */
@Composable
fun TrialClock(days: Int, modifier: Modifier = Modifier) {
    val slice = 360f / maxOf(1, days)
    val run = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        launch { delay(2500); Haptics.rigid() }
        delay(700)
        run.animateTo(360f - slice * 0.84f, tween(1800, easing = FastOutSlowInEasing))
    }
    Canvas(modifier.size(200.dp, 260.dp)) {
        val c = Offset(size.width / 2, size.height / 2)
        val k = density
        // Ring and crown
        drawCircle(Palette.yellow, 17 * k - 3.5f * k, Offset(c.x, c.y - 122 * k), style = Stroke(7 * k))
        val crown = RoundRect(Rect(Offset(c.x - 15 * k, c.y - 111 * k), Size(30 * k, 22 * k)), CornerRadius(5 * k))
        val crownPath = Path().apply { addRoundRect(crown) }
        drawPath(crownPath, Palette.yellow)
        drawPath(crownPath, giftOutline, style = Stroke(2 * k))

        drawCircle(Palette.yellow, 94 * k, c)
        drawCircle(giftOutline, 94 * k, c, style = Stroke(2.5f * k))
        drawCircle(Color.White, 76 * k, c)
        drawArc(Palette.green, 270f - slice, slice, true, Offset(c.x - 76 * k, c.y - 76 * k), Size(152 * k, 152 * k))
        for (i in 0 until maxOf(1, days)) {
            rotate(i * slice, c) {
                drawRect(giftOutline, Offset(c.x - 1 * k, c.y - 76 * k), Size(2 * k, 76 * k))
            }
        }
        drawCircle(giftOutline, 76 * k, c, style = Stroke(2.5f * k))
        // The hand stops at the start of the last day.
        rotate(run.value, c) {
            drawRoundRect(giftOutline, Offset(c.x - 3 * k, c.y - 58 * k), Size(6 * k, 62 * k), CornerRadius(3 * k))
        }
        drawCircle(Palette.orange, 8 * k, c)
        drawCircle(giftOutline, 8 * k, c, style = Stroke(2 * k))
    }
}

// MARK: - 2 · A notification the day before the trial ends

/** Preview of the notification sent the day before the end. */
@Composable
fun TrialNotificationPreview(modifier: Modifier = Modifier, large: Boolean = false) {
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(if (large) 22.dp else 14.dp))
            .background(if (large) (if (Palette.isDark) Palette.card else Color.White) else Palette.mistLight).padding(if (large) 14.dp else 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (large) 12.dp else 10.dp),
    ) {
        Image(painterResource(drawableId("logo")), null, contentScale = ContentScale.Crop,
            modifier = Modifier.size(if (large) 44.dp else 30.dp).clip(RoundedCornerShape(if (large) 10.dp else 7.dp)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(if (large) 2.dp else 0.dp)) {
            Text(L("Your trial ends tomorrow"), style = figtree(if (large) 16 else 13, FontWeight.Bold), color = Palette.ink)
            Text(L("Come back to your artworks."), style = figtree(if (large) 14 else 12), color = Palette.muted)
        }
        if (large) Text(L("now"), style = figtree(12), color = Palette.muted)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TrialNotifScreen(offer: TrialOffer, reminder: Boolean, onReminderChange: (Boolean) -> Unit, onNext: () -> Unit) {
    /** 0: nothing, 1: the bell, 2: the notification, 3: the texts, 4: the button. */
    var stage by remember { mutableIntStateOf(0) }
    /** Words of the title already turned bold: they thicken one by one. */
    var bold by remember { mutableIntStateOf(0) }
    val ring = remember { Animatable(-14f) }
    val words = remember { L("We'll send you a notification 1 day before your free trial ends").split(" ") }

    LaunchedEffect(Unit) {
        launch { delay(300); stage = 1 }
        launch {
            delay(800)
            Haptics.rigid()
            var to = 14f
            repeat(7) { ring.animateTo(to, tween(160, easing = FastOutSlowInEasing)); to = -to }
        }
        launch { delay(1900); stage = 2; Haptics.soft() }
        launch { delay(2700); stage = 3 }
        // The words turn bold one after the other, each with a tap under the finger.
        launch {
            delay(3300)
            for (i in 1..words.size) { delay(160); bold = i; Haptics.soft() }
            delay(600)
            stage = 4
        }
    }

    val s1 by animateFloatAsState(if (stage >= 1) 1f else 0f, Anim.settle(), label = "s1")
    val s2 by animateFloatAsState(if (stage >= 2) 1f else 0f, Anim.settle(), label = "s2")
    val s3 by animateFloatAsState(if (stage >= 3) 1f else 0f, Anim.settle(), label = "s3")
    val s4 by animateFloatAsState(if (stage >= 4) 1f else 0f, Anim.gentle(), label = "s4")

    Column(
        Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f).heightIn(min = 12.dp))

        Box(Modifier.size(190.dp).graphicsLayer { val s = 0.7f + 0.3f * s1; scaleX = s; scaleY = s; alpha = s1 }.clip(CircleShape).background(Palette.mist),
            contentAlignment = Alignment.Center) {
            Box {
                Icon(Icons.Rounded.Notifications, null, tint = Palette.blue,
                    modifier = Modifier.size(100.dp).graphicsLayer { rotationZ = ring.value; transformOrigin = TransformOrigin(0.5f, 0f) })
                Box(
                    Modifier.align(Alignment.TopEnd).offset(x = 8.dp, y = (-4).dp).size(34.dp)
                        .graphicsLayer { val s = 0.2f + 0.8f * s2; scaleX = s; scaleY = s; alpha = s2 }
                        .clip(CircleShape).background(Palette.orange),
                    contentAlignment = Alignment.Center,
                ) { Text("1", style = figtree(18, FontWeight.Bold), color = Color.White) }
            }
        }

        TrialNotificationPreview(
            Modifier.offset(y = (-26).dp).graphicsLayer { alpha = s2; translationY = (1 - s2) * -24.dp.toPx() }
                .shadow(18.dp, RoundedCornerShape(22.dp), ambientColor = Palette.blueDark.copy(alpha = 0.14f), spotColor = Palette.blueDark.copy(alpha = 0.2f)),
            large = true,
        )

        Column(
            Modifier.padding(top = 6.dp).graphicsLayer { alpha = s3; translationY = (1 - s3) * 14.dp.toPx() },
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Each word holds the room of its bold version from the start, so nothing moves:
            // the bold version simply fades in over the regular one, word after word.
            FlowRow(
                Modifier.fillMaxWidth().semantics { contentDescription = words.joinToString(" ") },
                horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.CenterHorizontally),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                words.forEachIndexed { i, word ->
                    val on by animateFloatAsState(if (i < bold) 1f else 0f, tween(320), label = "w$i")
                    Box(Modifier.graphicsLayer { val s = 0.97f + 0.03f * on; scaleX = s; scaleY = s }) {
                        Text(word, style = figtree(28, FontWeight.Normal), color = Palette.ink, softWrap = false,
                            modifier = Modifier.graphicsLayer { alpha = 1 - on })
                        Text(word, style = figtree(28, FontWeight.Bold), color = Palette.ink, softWrap = false,
                            modifier = Modifier.graphicsLayer { alpha = on })
                    }
                }
            }
            Text(L("No bad surprises."), style = figtree(18), color = Palette.muted, textAlign = TextAlign.Center)
        }

        Spacer(Modifier.weight(1f).heightIn(min = 16.dp))

        // The button only comes once the animation is over: no way to skip it.
        // No permission is asked and no notification is scheduled yet (same as iOS): to be set up before release.
        PillButton(L("Continue"), Modifier.graphicsLayer { alpha = s4 }, enabled = stage >= 4) { onNext() }
    }
}

// MARK: - 3 · How your trial works (timeline)

@Composable
fun TrialTimelineScreen(offer: TrialOffer, onNext: () -> Unit) {
    /** Timeline steps already revealed (0 to 3): they come in one by one, slowly. */
    var revealed by remember { mutableIntStateOf(0) }
    var done by remember { mutableStateOf(false) }
    val grow = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        launch { delay(700); grow.animateTo(1f, tween(3000, easing = FastOutSlowInEasing)) }
        launch {
            delay(700)
            for (i in 1..3) { if (i > 1) delay(1200); revealed = i; Haptics.soft() }
            delay(1200)
            done = true
        }
    }
    val d by animateFloatAsState(if (done) 1f else 0f, Anim.gentle(), label = "done")

    Column(
        Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(Modifier.padding(top = 44.dp).enter(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(L("How your free trial works"), style = figtree(30, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CheckBadge(Palette.green, 22.dp)
                Text(L("%@ today", offer.zeroPrice), style = figtree(17, FontWeight.Bold), color = Palette.ink)
            }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 20.dp))

        Column(
            Modifier.fillMaxWidth().enter(2.0)
                // The line connecting the three steps.
                .drawBehind {
                    val k = density
                    val full = (size.height - 80 * k).coerceAtLeast(0f)
                    val h = full * grow.value
                    if (h > 0f) drawRoundRect(
                        Brush.verticalGradient(listOf(Palette.blue, Palette.yellow, Palette.orange), startY = 36 * k, endY = 36 * k + h),
                        Offset(18 * k + 16.5f * k, 36 * k), Size(3 * k, h), CornerRadius(1.5f * k))
                }
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            TimelineRow(1, revealed, Icons.Rounded.LockOpen, Palette.blue, Color.White, L("Today"), L("All of Artura unlocks, no limits."))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TimelineRow(2, revealed, Icons.Rounded.Notifications, Palette.mist, Palette.blue,
                    L("Day %@ · your reminder", "${maxOf(1, offer.trialDays - 1)}"), L("The day before it ends, we'll let you know."))
                val r2 by animateFloatAsState(if (revealed >= 2) 1f else 0f, tween(800, easing = LinearOutSlowInEasing), label = "preview")
                TrialNotificationPreview(Modifier.padding(start = 48.dp).graphicsLayer { alpha = r2 })
            }
            TimelineRow(3, revealed, Icons.Rounded.Verified, Palette.bg, Palette.orange,
                L("Day %@ · Artura Pro", "${offer.trialDays}"), L("%@ per year. Cancel before then, in two taps.", offer.yearlyPrice))
        }

        Spacer(Modifier.weight(1f).heightIn(min = 20.dp))

        // The button only comes once the timeline has unfolded: no way to skip it.
        PillButton(L("Continue"), Modifier.graphicsLayer { alpha = d }, enabled = done) { onNext() }
    }
}

@Composable
private fun TimelineRow(step: Int, revealed: Int, icon: androidx.compose.ui.graphics.vector.ImageVector, fill: Color, tint: Color, title: String, text: String) {
    val v by animateFloatAsState(if (revealed >= step) 1f else 0f, tween(800, easing = LinearOutSlowInEasing), label = "row$step")
    Row(Modifier.graphicsLayer { alpha = v; translationY = (1 - v) * 8.dp.toPx() }, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(36.dp).clip(CircleShape).background(fill).border(1.5.dp, Palette.blue, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(17.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, style = figtree(16, FontWeight.Bold), color = Palette.ink)
            Text(text, style = figtree(14), color = Palette.muted)
        }
    }
}

// MARK: - 4 · The paywall

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrialScreen(offer: TrialOffer, extendedOffer: TrialOffer?, reminder: Boolean, onFinish: () -> Unit) {
    val pro = LocalPro.current
    val user = LocalUser.current
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    var canClose by remember { mutableStateOf(false) }
    var showExitOffer by remember { mutableStateOf(OnboardingDebug.flag("onbExitOffer")) }
    var exitOfferSeen by remember { mutableStateOf(false) }
    var showPlans by remember { mutableStateOf(false) }
    /** Delay before the close button appears, in seconds. */
    val closeDelay = 6

    LaunchedEffect(Unit) { delay(closeDelay * 1000L); canClose = true }
    val closeAlpha by animateFloatAsState(if (canClose) 1f else 0f, tween(900), label = "close")

    /** How much cheaper the gift offer is than the regular yearly price, in percent (0 if it isn't). */
    fun discount(gift: TrialOffer): Int {
        if (offer.yearlyAmount <= BigDecimal.ZERO || gift.yearlyAmount >= offer.yearlyAmount) return 0
        val ratio = BigDecimal.ONE - gift.yearlyAmount.divide(offer.yearlyAmount, 6, RoundingMode.HALF_UP)
        return (ratio.toDouble() * 100).roundToInt()
    }

    /** Shows the gift offer if it hasn't been shown yet. Returns false when there is nothing to show. */
    fun presentExitOffer(): Boolean {
        val ext = extendedOffer ?: return false
        if (exitOfferSeen || ext.trialDays <= offer.trialDays) return false
        exitOfferSeen = true
        Haptics.press()
        Analytics.track("paywall_viewed", mapOf("kind" to "exit_offer", "product" to (ext.product?.id ?: "preview")))
        showExitOffer = true
        return true
    }

    fun finishWith(chosen: TrialOffer) {
        if (reminder) Reminder.scheduleTrialEnding(context, chosen.trialDays)
        onFinish()
    }

    fun buy(chosen: TrialOffer) {
        val product = chosen.product
        if (product == null) {
            // No product to buy yet (not created in the Play Console): the flow simply ends.
            showExitOffer = false
            onFinish()
            return
        }
        val activity = context as? Activity ?: return
        scope.launch {
            val ok = pro.purchase(activity, product)
            if (ok) {
                Haptics.success()
                showExitOffer = false
                finishWith(chosen)
            } else if (pro.lastError == null && !showExitOffer) {
                // The Play sheet was opened, then dismissed: this is the moment for the gift offer.
                delay(450)
                presentExitOffer()
            }
        }
    }

    fun close() {
        // One last offer before leaving, only once.
        if (!presentExitOffer()) onFinish()
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding().padding(bottom = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        // The close button: discreet, no background, and only after a while.
        Row(Modifier.fillMaxWidth().padding(start = 8.dp)) {
            Box(
                Modifier.size(44.dp, 36.dp).graphicsLayer { alpha = closeAlpha }
                    .semantics { contentDescription = L("Close and continue for free") }
                    .pressable(enabled = canClose) { close() },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, null, tint = Palette.muted.copy(alpha = 0.7f), modifier = Modifier.size(20.dp)) }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 8.dp))

        ArtImage("ill_premium", Modifier.size(210.dp).enter().clip(RoundedCornerShape(36.dp)), anchor = Offset(0.5f, 0.4f))

        Column(
            Modifier.padding(horizontal = 28.dp).padding(top = 32.dp).enter(2.0),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            // "Try 3 days for free," highlighted, then the price in plain words.
            val line = buildAnnotatedString {
                // L: highlighted first half of "Try 3 days for free, then $4.99 per month (billed yearly at $59.99)"
                withStyle(SpanStyle(color = Palette.blue, background = Palette.mist)) { append(L(" Try %@ days for free, ", "${offer.trialDays}")) }
                // L: second half of the same sentence, after the highlighted "Try 3 days for free,"
                withStyle(SpanStyle(color = Palette.ink)) { append(L(" then %@ per month (billed yearly at %@)", offer.monthlyPrice, offer.yearlyPrice)) }
            }
            Text(line, style = figtree(24, FontWeight.Medium).copy(lineHeight = 36.sp), textAlign = TextAlign.Center,
                modifier = Modifier.semantics {
                    contentDescription = L("Try %@ days for free, then %@ per month, billed yearly at %@", "${offer.trialDays}", offer.monthlyPrice, offer.yearlyPrice)
                })
            Box(Modifier.height(44.dp).pressable { Haptics.tap(); showPlans = true }, contentAlignment = Alignment.Center) {
                Text(L("View other plans"), style = figtree(16, FontWeight.SemiBold), color = Palette.muted)
            }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 12.dp))

        Column(Modifier.padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            pro.lastError?.let { Text(it, style = AType.caption, color = Palette.red, textAlign = TextAlign.Center) }
            Row(Modifier.padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.VerifiedUser, null, tint = Palette.muted, modifier = Modifier.size(16.dp))
                Text(L("Secured with Google Play"), style = figtree(14), color = Palette.muted)
            }
        }

        // The action, on a pale blue band
        Box(
            Modifier.padding(horizontal = 8.dp).clip(RoundedCornerShape(24.dp)).background(Palette.mist)
                .padding(horizontal = 16.dp).padding(top = 14.dp, bottom = 17.dp)
        ) {
            PillButton(height = 66.dp, enabled = !pro.isPurchasing, onClick = { buy(offer) }) {
                if (pro.isPurchasing) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(L("Start free trial"), style = figtree(18, FontWeight.Bold), color = Color.White)
                        Text(L("2 taps to start, super easy to cancel"), style = figtree(13), color = Color.White.copy(alpha = 0.85f))
                    }
                }
            }
        }

        Row(Modifier.fillMaxWidth().height(40.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            LegalLink(L("Terms"), Modifier.weight(1f)) { uri.openUri(Legal.terms) }
            Legal.privacy?.let { url -> LegalLink(L("Privacy Policy"), Modifier.weight(1f)) { uri.openUri(url) } }
            LegalLink(L("Restore Purchase"), Modifier.weight(1f)) {
                scope.launch {
                    pro.restore()
                    if (pro.isPro) { Haptics.success(); onFinish() }
                }
            }
        }
    }

    if (showPlans) {
        ModalBottomSheet(
            onDismissRequest = { showPlans = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Palette.bg,
            dragHandle = null,
        ) {
            PaywallScreen(onClose = {
                showPlans = false
                if (pro.isPro) onFinish()
            })
        }
    }
    val ext = extendedOffer
    if (showExitOffer && ext != null) {
        ModalBottomSheet(
            onDismissRequest = { showExitOffer = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Palette.bg,
            shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
        ) {
            ExitOfferSheet(
                pro = pro, offer = ext, baseDays = offer.trialDays, basePrice = offer.yearlyPrice, discount = discount(ext),
                firstName = user.profile.firstName,
                onAccept = { buy(ext) },
                onDecline = {
                    showExitOffer = false
                    scope.launch { delay(350); onFinish() }
                },
            )
        }
    }
}

@Composable
private fun LegalLink(title: String, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(40.dp).pressable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(title, style = figtree(13), color = Palette.muted, textAlign = TextAlign.Center, maxLines = 1)
    }
}

// MARK: - 4 · "Wait…": the one-week pass

/** Museum ticket: a rounded rectangle with two notches, where the stub tears off. `notch`: position of the notches, as a fraction of the height. */
private class TicketShape(private val notch: Float = 0.72f) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val r = 11 * density.density
        val y = size.height * notch
        val body = Path().apply { addRoundRect(RoundRect(Rect(Offset.Zero, size), CornerRadius(22 * density.density))) }
        val notches = Path().apply {
            addOval(Rect(-r, y - r, r, y + r))
            addOval(Rect(size.width - r, y - r, size.width + r, y + r))
        }
        return Outline.Generic(Path.combine(PathOperation.Difference, body, notches))
    }
}

@Composable
fun ExitOfferSheet(
    pro: ProStore,
    offer: TrialOffer,
    /** Length of the base trial, struck through next to the new one. */
    baseDays: Int,
    /** Regular yearly price, struck through next to the gift price. */
    basePrice: String,
    /** Discount on the yearly price, in percent (0 = none). */
    discount: Int,
    firstName: String?,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    var filled by remember { mutableIntStateOf(0) }
    var stamped by remember { mutableStateOf(false) }
    val extraDays = maxOf(0, offer.trialDays - baseDays)
    val title = if (!firstName.isNullOrEmpty()) L("Wait, %@…", firstName) else L("Wait…")

    LaunchedEffect(Unit) {
        Haptics.soft()
        // The days fill in one by one: first the trial, then the free days.
        launch {
            delay(800)
            for (i in 1..maxOf(1, offer.trialDays)) {
                delay(140)
                filled = i
                if (i > baseDays) Haptics.rigid() else Haptics.whisper()
            }
        }
        delay(1000L + offer.trialDays * 140L)
        stamped = true
        Haptics.heavy()
    }
    val stamp by animateFloatAsState(if (stamped) 1f else 0f, Anim.settle(), label = "stamp")

    Column(
        Modifier.fillMaxWidth().background(Palette.bg).navigationBarsPadding().padding(horizontal = 24.dp).padding(bottom = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // The Mona Lisa holds the visitor back: she is the one offering the pass.
        MascotBubble(100.dp, Modifier.padding(top = 18.dp).enter()) {
            Text(title, style = figtree(26, FontWeight.Bold), color = Palette.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(6.dp))
            Text(
                if (discount > 0) L("Before you go: %@ days free and %@%% off, so you can at least try Artura.", "${offer.trialDays}", "$discount")
                else L("Here are %@ extra days to explore all of Artura.", "$extraDays"),
                style = figtree(16), color = Palette.muted, textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.height(10.dp))

        // The pass, drawn like a museum admission ticket.
        val ticket = TicketShape()
        Column(
            Modifier.fillMaxWidth().enter(2.0)
                .semantics {
                    contentDescription = if (discount > 0)
                        L("Visitor pass: %@ days free instead of %@, then %@ per year instead of %@", "${offer.trialDays}", "$baseDays", offer.yearlyPrice, basePrice)
                    else L("Visitor pass: %@ days free instead of %@", "${offer.trialDays}", "$baseDays")
                }
                .shadow(16.dp, ticket, ambientColor = Palette.blueDark.copy(alpha = 0.12f), spotColor = Palette.blueDark.copy(alpha = 0.18f))
                .background(Palette.bg, ticket)
                .border(1.5.dp, Palette.blue, ticket)
        ) {
            Column(Modifier.padding(horizontal = 18.dp).padding(top = 16.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(L("ARTURA PRO · VISITOR PASS"), style = figtree(11, FontWeight.Bold).copy(letterSpacing = 2.sp), color = Palette.muted)
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(L("%@ days free", "${offer.trialDays}"), style = figtree(30, FontWeight.Bold), color = Palette.ink,
                        modifier = Modifier.alignByBaseline())
                    Text(L("%@ days", "$baseDays"), style = figtree(16, FontWeight.Medium).copy(textDecoration = TextDecoration.LineThrough),
                        color = Palette.muted, modifier = Modifier.alignByBaseline())
                }
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    for (i in 0 until maxOf(1, offer.trialDays)) {
                        val color = if (i < filled) (if (i < baseDays) Palette.blue else Palette.green) else Palette.line
                        val c by androidx.compose.animation.animateColorAsState(color, tween(250), label = "day$i")
                        Box(Modifier.weight(1f).height(20.dp).clip(RoundedCornerShape(7.dp)).background(c))
                    }
                }
                Row {
                    Text(L("Days 1–%@: your trial", "$baseDays"), style = figtree(13, FontWeight.Medium), color = Palette.blue)
                    Spacer(Modifier.weight(1f).width(8.dp))
                    Text(L("Days %@–%@: on us", "${baseDays + 1}", "${offer.trialDays}"), style = figtree(13, FontWeight.Bold), color = Palette.green)
                }
            }
            // The tear line of the stub
            Canvas(Modifier.fillMaxWidth().padding(horizontal = 18.dp).height(1.5.dp)) {
                drawLine(Palette.lip, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 1.5.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx())))
            }
            Row(Modifier.padding(horizontal = 18.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    if (discount > 0) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(L("%@ / year", offer.yearlyPrice), style = figtree(17, FontWeight.Bold), color = Palette.ink, maxLines = 1,
                                modifier = Modifier.alignByBaseline())
                            Text(basePrice, style = figtree(14, FontWeight.Medium).copy(textDecoration = TextDecoration.LineThrough),
                                color = Palette.muted, maxLines = 1, modifier = Modifier.alignByBaseline())
                        }
                        Text(L("Full access, after your free trial"), style = figtree(13), color = Palette.muted)
                    } else {
                        Text(L("Full access"), style = figtree(15, FontWeight.Bold), color = Palette.ink)
                        Text(L("Lessons, games and movements"), style = figtree(13), color = Palette.muted)
                    }
                }
                Spacer(Modifier.width(8.dp))
                // The "free" stamp
                Box(
                    Modifier.graphicsLayer { rotationZ = -6f; val s = 1.6f - 0.6f * stamp; scaleX = s; scaleY = s; alpha = stamp }
                        .height(28.dp).border(2.dp, Palette.green, RoundedCornerShape(8.dp)).padding(horizontal = 9.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(if (discount > 0) L("%@%% OFF", "$discount") else L("+ %@ DAYS FREE", "$extraDays"),
                        style = figtree(11, FontWeight.Bold).copy(letterSpacing = 0.5.sp), color = Palette.green, maxLines = 1, softWrap = false)
                }
            }
        }

        Spacer(Modifier.height(10.dp))

        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            pro.lastError?.let { Text(it, style = AType.caption, color = Palette.red) }
            PillButton(enabled = !pro.isPurchasing, onClick = onAccept) {
                if (pro.isPurchasing) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                else Text(L("Get my %@-day pass", "${offer.trialDays}"), style = AType.bodyStrong, color = Color.White)
            }
            Box(Modifier.height(44.dp).pressable { Haptics.tap(); onDecline() }, contentAlignment = Alignment.Center) {
                Text(L("No thanks"), style = figtree(15, FontWeight.Medium).copy(textDecoration = TextDecoration.Underline), color = Palette.muted)
            }
            Text(L("%@ today, then %@ per year after %@ days.", offer.zeroPrice, offer.yearlyPrice, "${offer.trialDays}"),
                style = AType.caption, color = Palette.muted, textAlign = TextAlign.Center)
        }
    }
}

// MARK: - Profile paywall (yearly or monthly choice)

/** The Artura Pro paywall opened from the app (feed, profile). Present it in a FullScreenCover. */
@Composable
fun PaywallScreen(onClose: () -> Unit) {
    val pro = LocalPro.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var yearlySelected by remember { mutableStateOf(true) }
    val benefits = listOf(L("All games, no daily limit"), L("All paths and their lessons"), L("Stories in audio"), L("No ads"))
    val selected = if (yearlySelected) pro.yearly else pro.monthly

    LaunchedEffect(Unit) {
        Analytics.track("paywall_viewed", mapOf("kind" to "plans"))
        if (pro.products.isEmpty()) pro.loadProducts()
    }

    fun purchase() {
        val product = selected ?: return
        val activity = context as? Activity ?: return
        scope.launch {
            if (pro.purchase(activity, product)) { Haptics.success(); onClose() }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.fillMaxWidth().height(240.dp)) {
            ArtImage("ill_premium", Modifier.fillMaxSize().clip(ArcHeaderShape), anchor = Offset(0.5f, 0.4f))
            Box(
                Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(end = 16.dp, top = 8.dp).size(44.dp)
                    .semantics { contentDescription = L("Close and continue for free") }
                    .pressable(onClick = onClose).clip(CircleShape).background(Palette.bg),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, null, tint = Palette.ink, modifier = Modifier.size(20.dp)) }
        }

        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-20).dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(L("Start your 3 days of Artura Pro"), style = AType.titleSmall, color = Palette.ink, textAlign = TextAlign.Center)
            Column(Modifier.fillMaxWidth().padding(horizontal = 6.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                benefits.forEachIndexed { i, benefit ->
                    Row(Modifier.appearUp(0.06 * i), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Rounded.Check, null, tint = Palette.green, modifier = Modifier.size(18.dp))
                        Text(benefit, style = figtree(15), color = Palette.ink)
                    }
                }
            }
            PlanRow(L("Yearly"), pro.yearly?.let { L("%@ per year", it.displayPrice) }, L("3 days free"), yearlySelected) { yearlySelected = true }
            PlanRow(L("Monthly"), pro.monthly?.let { L("%@ per month", it.displayPrice) }, null, !yearlySelected) { yearlySelected = false }
            pro.lastError?.let { Text(it, style = AType.caption, color = Palette.red) }
        }

        Spacer(Modifier.weight(1f).heightIn(min = 12.dp))

        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 4.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)) {
            PillButton(Modifier.graphicsLayer { alpha = if (selected == null) 0.4f else 1f },
                enabled = selected != null && !pro.isPurchasing, onClick = { purchase() }) {
                if (pro.isPurchasing) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
                // The monthly plan has no free trial.
                else Text(if (selected != null && selected.trialDays == null) L("Continue") else L("Start free trial"),
                    style = AType.bodyStrong, color = Color.White)
            }
            TextLinkButton(L("Not now"), onClick = onClose)
            Box(Modifier.heightIn(min = 44.dp).pressable {
                scope.launch {
                    pro.restore()
                    if (pro.isPro) { Haptics.success(); onClose() }
                }
            }, contentAlignment = Alignment.Center) {
                Text(L("Restore purchases"), style = figtree(12), color = Palette.muted)
            }
        }
    }
}

@Composable
private fun PlanRow(title: String, price: String?, badge: String?, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().heightIn(min = if (badge == null) 60.dp else 72.dp)
            .pressable { Haptics.selection(); onClick() }
            .clip(shape).background(if (selected) Palette.mistLight else Palette.card)
            .border(2.dp, if (selected) Palette.blue else Color.Transparent, shape)
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            if (badge != null) TagPill(badge)
            Text(title, style = AType.bodyStrong, color = Palette.ink)
        }
        Text(price ?: L("Price unavailable"), style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
        if (selected) CheckBadge()
    }
}
