package com.vikstudios.artura.learn

import android.app.Activity
import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.SouthWest
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.RemoteImage
import com.vikstudios.artura.core.drawableId
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.GuideLine
import com.vikstudios.artura.data.LessonBlock
import com.vikstudios.artura.data.Spot
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.sqrt

/**
 * The painting full screen on a black background: guided tour, "find it", composition lines, palette and
 * free zoom. The camera moves across the canvas; markers are drawn in the painting's coordinate space
 * (0…1), so they follow the zoom.
 */
@Composable
fun PaintingStudio(artwork: Artwork, block: LessonBlock, onDone: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Camera: the point of the painting placed at the center, and the magnification.
    val cx = remember { Animatable(0.5f) }
    val cy = remember { Animatable(0.5f) }
    val zoomAnim = remember { Animatable(1f) }
    // Progress within the block (0 = overview).
    var step by remember { mutableIntStateOf(0) }
    var locked by remember { mutableStateOf(true) }
    var closing by remember { mutableStateOf(false) }
    // "Find it"
    var guess by remember { mutableStateOf<Offset?>(null) }
    var found by remember { mutableStateOf<Boolean?>(null) }
    // Palette and free zoom
    var selected by remember { mutableStateOf<Int?>(null) }
    var swatchesShown by remember { mutableIntStateOf(0) }
    var pinched by remember { mutableStateOf(false) }
    var unlockJob by remember { mutableStateOf<Job?>(null) }

    val spots = block.spots ?: emptyList()
    val lines = block.lines ?: emptyList()
    val swatches = block.swatches ?: emptyList()
    val usesButton = block.type == "palette" || block.type == "explore"
    val stepCount = when (block.type) {
        "tour" -> spots.size
        "lines" -> lines.size
        else -> 0
    }
    val bundledId = drawableId(artwork.canvasImage)
    val imageAspect = remember(artwork.id) {
        artwork.aspect?.takeIf { it > 0 }?.toFloat() ?: run {
            if (bundledId == 0) 0.8f else {
                val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeResource(context.resources, bundledId, o)
                if (o.outHeight > 0) o.outWidth.toFloat() / o.outHeight else 0.8f
            }
        }
    }

    val pulse by rememberInfiniteTransition(label = "pulse").animateFloat(
        0f, 1f, infiniteRepeatable(tween(1300, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "pulse")

    // Light status bar icons on the dark background.
    val view = LocalView.current
    DisposableEffect(Unit) {
        val window = (view.context as? Activity)?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val old = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightStatusBars = false
        onDispose { if (old != null) controller.isAppearanceLightStatusBars = old }
    }

    fun unlock(after: Long) {
        locked = true
        unlockJob?.cancel()
        unlockJob = scope.launch { delay(after); locked = false }
    }

    fun move(x: Float, y: Float, target: Float, duration: Int = 900) {
        val spec = tween<Float>(duration, easing = FastOutSlowInEasing)
        scope.launch { cx.animateTo(x, spec) }
        scope.launch { cy.animateTo(y, spec) }
        scope.launch { zoomAnim.animateTo(target, spec) }
    }

    /** Zoom out, then hand control back to the lesson. */
    fun finish() {
        if (closing) return
        closing = true
        Haptics.soft()
        step = 0; selected = null; found = null; guess = null
        val wasZoomed = zoomAnim.value > 1.05f
        move(0.5f, 0.5f, 1f, 600)
        scope.launch { delay(if (wasZoomed) 650 else 150); onDone() }
    }

    fun advance() {
        if (locked || closing) { Haptics.whisper(); return }
        when (block.type) {
            "tour" -> if (step < spots.size) {
                Haptics.press()
                val spot = spots[step]
                step += 1
                move(spot.x.toFloat(), spot.y.toFloat(), (spot.zoom ?: 2.5).toFloat())
                unlock(1500)
            } else finish()
            "lines" -> if (step < lines.size) {
                Haptics.press()
                step += 1
                unlock(1200)
            } else finish()
            else -> finish()
        }
    }

    fun focus(index: Int) {
        val spot = spots.getOrNull(index) ?: return
        Haptics.press()
        selected = index
        move(spot.x.toFloat(), spot.y.toFloat(), (spot.zoom ?: 2.5).toFloat(), 700)
    }

    LaunchedEffect(Unit) {
        unlock(700)
        if (block.type == "palette") {
            for (i in 1..maxOf(1, swatches.size)) {
                launch {
                    delay((300 + 140 * i).toLong())
                    swatchesShown = i
                    Haptics.soft()
                }
            }
        }
    }

    BackHandler { finish() }

    Column(Modifier.fillMaxSize().background(hexColor(0x0E0D0C)).statusBarsPadding()) {
        // MARK: Top bar
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f))
                    .pressable { Haptics.tap(); finish() }
                    .semantics { contentDescription = L("Close and return to the lesson") },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
            Row(
                Modifier.height(32.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f)).padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(block.interactiveIcon, null, tint = Color.White, modifier = Modifier.size(15.dp))
                Text(block.interactiveTitle, style = figtree(14, FontWeight.SemiBold), color = Color.White, maxLines = 1)
            }
            Spacer(Modifier.weight(1f))
            if (stepCount > 0) {
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    for (i in 0 until stepCount) {
                        val w by animateFloatAsState(if (i == step - 1) 16f else 6f, tween(200), label = "dot")
                        Box(Modifier.size(w.dp, 6.dp).clip(CircleShape)
                            .background(if (i < step) Color.White else Color.White.copy(alpha = 0.28f)))
                    }
                }
            }
        }

        // MARK: Painting
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().clipToBounds()) {
            val density = LocalDensity.current
            val cw = constraints.maxWidth.toFloat()
            val ch = constraints.maxHeight.toFloat()
            // Fitted size of the painting, in px.
            val (fw, fh) = if (cw <= 0 || ch <= 0) 0f to 0f
                else if (cw / ch > imageAspect) ch * imageAspect to ch else cw to cw / imageAspect

            /** Keeps the camera from leaving the painting. */
            fun clamped(x: Float, y: Float, zoom: Float): Pair<Float, Float> {
                if (fw <= 0 || fh <= 0) return x to y
                val halfX = cw / (2 * fw * zoom)
                val halfY = ch / (2 * fh * zoom)
                val nx = if (halfX >= 0.5f) 0.5f else x.coerceIn(halfX, 1 - halfX)
                val ny = if (halfY >= 0.5f) 0.5f else y.coerceIn(halfY, 1 - halfY)
                return nx to ny
            }

            /** "Find it": compare the tap to the target, then the camera moves there either way. */
            fun evaluate(location: Offset) {
                val target = spots.firstOrNull() ?: return
                if (locked || fw <= 0) return
                val px = 0.5f + (location.x - cw / 2) / fw
                val py = 0.5f + (location.y - ch / 2) / fh
                if (px !in 0f..1f || py !in 0f..1f) return
                val dx = px - target.x
                val dy = (py - target.y) * fh / fw
                val hit = sqrt(dx * dx + dy * dy) <= maxOf((target.r ?: 0.06) * 1.8, 0.08)
                guess = Offset(px, py)
                if (hit) Haptics.success() else Haptics.rigid()
                scope.launch {
                    delay(350)
                    found = hit
                    move(target.x.toFloat(), target.y.toFloat(), (target.zoom ?: 2.5).toFloat())
                    unlock(1500)
                }
            }

            fun tapCanvas(location: Offset) {
                when (block.type) {
                    "find" -> if (found == null) evaluate(location) else advance()
                    "explore" -> if (selected != null) selected = null
                    "palette" -> {}
                    else -> advance()
                }
            }

            val zoom = zoomAnim.value
            val (camX, camY) = clamped(cx.value, cy.value, zoom)
            val fwDp = with(density) { fw.toDp() }
            val fhDp = with(density) { fh.toDp() }

            Box(
                Modifier
                    .fillMaxSize()
                    .pointerInput(block.type, fw, fh) {
                        detectTapGestures { tapCanvas(it) }
                    }
                    .then(
                        if (block.type == "explore") Modifier
                            .pointerInput(fw, fh) {
                                detectTransformGestures { _, pan, zoomChange, _ ->
                                    if (fw <= 0) return@detectTransformGestures
                                    val z = (zoomAnim.value * zoomChange).coerceIn(1f, 6f)
                                    if (zoomChange != 1f) pinched = true
                                    val (bx, by) = clamped(cx.value, cy.value, zoomAnim.value)
                                    val (nx, ny) = clamped(bx - pan.x / (fw * z), by - pan.y / (fh * z), z)
                                    scope.launch { zoomAnim.snapTo(z); cx.snapTo(nx); cy.snapTo(ny) }
                                }
                            }
                            .pointerInput(Unit) {
                                awaitEachGesture {
                                    awaitFirstDown(requireUnconsumed = false)
                                    do { val event = awaitPointerEvent() } while (event.changes.any { it.pressed })
                                    if (pinched) { pinched = false; Haptics.soft() }
                                }
                            }
                        else Modifier
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier
                        .size(fwDp, fhDp)
                        .graphicsLayer {
                            scaleX = zoom; scaleY = zoom
                            translationX = (0.5f - camX) * fw * zoom
                            translationY = (0.5f - camY) * fh * zoom
                        }
                ) {
                    if (artwork.isRemote) {
                        RemoteImage(artwork.canvasImage, Modifier.fillMaxSize(), ContentScale.FillBounds)
                    } else if (bundledId != 0) {
                        Image(painterResource(bundledId), null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
                    }
                    StudioOverlay(
                        block = block, spots = spots, lines = lines, swatches = swatches.map { it.image },
                        step = step, zoom = zoom, guess = guess, found = found, selected = selected, pulse = pulse,
                        onFocus = { focus(it) },
                    )
                }
            }
        }

        // MARK: Bottom panel
        val caption: Pair<String?, String> = when (block.type) {
            "tour" -> spots.getOrNull(step - 1)?.let { it.title to (it.text ?: "") }
                ?: (null to (block.text ?: L("First, take in the whole painting.")))
            "find" -> {
                val target = spots.firstOrNull()
                if (found != null && target != null) (if (found == true) L("Found it!") else L("Close. It was here.")) to (target.text ?: "")
                else L("Your turn") to (block.text ?: "")
            }
            "lines" -> lines.getOrNull(step - 1)?.let { it.label to it.text }
                ?: (null to (block.text ?: L("How is this painting built?")))
            "palette" -> selected?.let { swatches.getOrNull(it) }?.let { it.name to it.text }
                ?: (null to (block.text ?: L("Tap a color to see where it hides.")))
            else -> selected?.let { spots.getOrNull(it) }?.let { it.title to (it.text ?: "") }
                ?: (null to (block.text ?: L("Pinch to zoom, drag to move around. Tap a dot for a detail.")))
        }
        val hint = if (block.type == "find" && found == null) L("Tap the painting") else {
            val last = (block.type == "find" && found != null) || (stepCount > 0 && step >= stepCount)
            if (last) L("Tap to return to the lesson") else L("Tap to continue")
        }
        val hintAlpha by animateFloatAsState(if (locked) 0f else 1f, tween(300), label = "hint")

        Column(
            Modifier
                .fillMaxWidth()
                .height(if (block.type == "palette") 236.dp else 196.dp)
                .background(hexColor(0x1B1917))
                .clickable(remember { MutableInteractionSource() }, null) {
                    if (!usesButton && !(block.type == "find" && found == null)) advance()
                }
                .padding(horizontal = 20.dp)
                .padding(top = 14.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (block.type == "palette") {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    swatches.forEachIndexed { i, swatch ->
                        val shown = i < swatchesShown
                        val t by animateFloatAsState(if (shown) 1f else 0f, tween(400, easing = LinearOutSlowInEasing), label = "sw$i")
                        val isSel = selected == i
                        Box(
                            Modifier
                                .weight(1f)
                                .height(48.dp)
                                .graphicsLayer {
                                    alpha = t
                                    translationY = (1 - t) * -40.dp.toPx()
                                    val s = 0.5f + 0.5f * t
                                    scaleX = s; scaleY = s
                                }
                                .pressable {
                                    Haptics.selection()
                                    selected = if (selected == i) null else i
                                }
                                .semantics { contentDescription = swatch.name }
                                .clip(RoundedCornerShape(14.dp))
                                .background(hexColor(swatch.hex))
                                .border(if (isSel) 3.dp else 1.dp, Color.White.copy(alpha = if (isSel) 1f else 0.35f), RoundedCornerShape(14.dp))
                        )
                    }
                }
            }
            AnimatedContent(
                targetState = caption,
                transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(200)) },
                label = "caption",
            ) { (title, text) ->
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (title != null) Text(title, style = figtree(18, FontWeight.SemiBold), color = Color.White)
                    Text(text, style = figtree(15).copy(lineHeight = 21.sp), color = Color.White.copy(alpha = 0.88f))
                }
            }
            Spacer(Modifier.weight(1f))
            if (usesButton) {
                PillButton(L("Back to the lesson")) { finish() }
            } else {
                Text(
                    hint, style = figtree(13, FontWeight.Medium), color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().graphicsLayer { alpha = hintAlpha * (0.45f + 0.55f * pulse) },
                )
            }
        }
        Box(Modifier.fillMaxWidth().navigationBarsPadding())
    }
}

/** Markers drawn in the painting's coordinate space (the parent box has the painting's fitted size). */
@Composable
private fun StudioOverlay(
    block: LessonBlock,
    spots: List<Spot>,
    lines: List<GuideLine>,
    swatches: List<String>,
    step: Int,
    zoom: Float,
    guess: Offset?,
    found: Boolean?,
    selected: Int?,
    pulse: Float,
    onFocus: (Int) -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = maxWidth
        val h = maxHeight
        when (block.type) {
            "tour" -> spots.getOrNull(step - 1)?.let { spot ->
                androidx.compose.runtime.key(step) { SpotMark(spot, zoom, delayMs = 750) }
            }
            "find" -> {
                if (guess != null) {
                    Box(
                        Modifier
                            .offset(w * guess.x - 7.dp, h * guess.y - 7.dp)
                            .size(14.dp)
                            .graphicsLayer { scaleX = 1 / zoom; scaleY = 1 / zoom }
                            .clip(CircleShape).background(Color.White)
                            .border(2.dp, Color.Black.copy(alpha = 0.5f), CircleShape)
                    )
                }
                val target = spots.firstOrNull()
                if (found != null && target != null) {
                    SpotMark(target, zoom, delayMs = 750, color = if (found) Palette.green else Palette.yellow)
                }
            }
            "lines" -> {
                val dim by animateFloatAsState(if (step >= 1) 0.35f else 0f, tween(300), label = "dim")
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = dim)))
                lines.forEachIndexed { i, line ->
                    if (i < step) androidx.compose.runtime.key(i) { DrawnLine(line, emphasised = i == step - 1) }
                }
            }
            "palette" -> swatches.forEachIndexed { i, image ->
                val a by animateFloatAsState(if (selected == i) 1f else 0f, tween(450, easing = FastOutSlowInEasing), label = "pal$i")
                val id = drawableId(image)
                if (id != 0) Image(painterResource(id), null, Modifier.fillMaxSize().graphicsLayer { alpha = a }, contentScale = ContentScale.FillBounds)
            }
            else -> spots.forEachIndexed { i, spot ->
                val isSel = selected == i
                Box(
                    Modifier
                        .offset(w * spot.x.toFloat() - 24.dp, h * spot.y.toFloat() - 24.dp)
                        .size(48.dp)
                        .graphicsLayer { scaleX = 1 / zoom; scaleY = 1 / zoom }
                        .clip(CircleShape)
                        .clickable(remember { MutableInteractionSource() }, null) { onFocus(i) }
                        .semantics { contentDescription = spot.title ?: L("Detail") },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(44.dp).graphicsLayer { val s = 0.7f + 0.3f * pulse; scaleX = s; scaleY = s }
                            .clip(CircleShape).background(Color.White.copy(alpha = if (isSel) 0f else 0.25f))
                    )
                    Box(
                        Modifier.size(18.dp).clip(CircleShape).background(if (isSel) Palette.yellow else Color.White)
                            .border(2.dp, Color.Black.copy(alpha = 0.45f), CircleShape)
                    )
                }
            }
        }
    }
}

/** Dims the painting around the detail, then draws the circle, frame or arrow. */
@Composable
private fun SpotMark(spot: Spot, zoom: Float, delayMs: Long = 0, color: Color = Color.White) {
    val progress = remember { Animatable(0f) }
    val dim = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(delayMs)
        Haptics.rigid()
        launch { dim.animateTo(1f, tween(500, easing = LinearOutSlowInEasing)) }
        progress.animateTo(1f, tween(700, easing = FastOutSlowInEasing))
    }
    val isRect = spot.shape == "rect"
    if (spot.shape == "arrow") {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            Icon(
                Icons.Rounded.SouthWest, null, tint = Palette.yellow,
                modifier = Modifier
                    .offset(maxWidth * spot.x.toFloat() + (30 / zoom).dp - 20.dp, maxHeight * spot.y.toFloat() - (30 / zoom).dp - 20.dp)
                    .size(40.dp)
                    .graphicsLayer { scaleX = 1 / zoom; scaleY = 1 / zoom; alpha = progress.value }
            )
        }
        return
    }
    Canvas(Modifier.fillMaxSize()) {
        val radius = ((spot.r ?: 0.07) * size.width).toFloat()
        val point = Offset(spot.x.toFloat() * size.width, spot.y.toFloat() * size.height)
        val k = if (isRect) 1.35f else 1f
        val frame = Rect(point.x - radius, point.y - radius * k, point.x + radius, point.y + radius * k)
        // A large rectangle with a hole in it: everything but the detail is dimmed.
        val hole = Path().apply {
            fillType = PathFillType.EvenOdd
            addRect(Rect(-size.width, -size.height, size.width * 2, size.height * 2))
            if (isRect) addRoundRect(RoundRect(frame, CornerRadius(frame.width * 0.09f)))
            else addOval(frame)
        }
        drawPath(hole, Color.Black.copy(alpha = 0.55f * dim.value))
        val stroke = Stroke(width = 3.dp.toPx() / zoom, cap = StrokeCap.Round)
        if (isRect) {
            val outline = Path().apply { addRoundRect(RoundRect(frame, CornerRadius(radius * 0.18f))) }
            val measure = PathMeasure().apply { setPath(outline, false) }
            val part = Path()
            measure.getSegment(0f, measure.length * progress.value, part, true)
            drawPath(part, color, style = stroke)
        } else {
            drawArc(color, -90f, 360f * progress.value, false, frame.topLeft, Size(frame.width, frame.height), style = stroke)
        }
    }
}

/** A composition line, drawn progressively. */
@Composable
private fun DrawnLine(line: GuideLine, emphasised: Boolean) {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        Haptics.rigid()
        progress.animateTo(1f, tween(1000, easing = FastOutSlowInEasing))
    }
    val width by animateFloatAsState(if (emphasised) 4f else 2.5f, tween(300), label = "lw")
    val tint = if (emphasised) Palette.yellow else Color.White.copy(alpha = 0.75f)
    Canvas(Modifier.fillMaxSize()) {
        val pts = line.points.filter { it.size == 2 }.map { Offset(it[0].toFloat() * size.width, it[1].toFloat() * size.height) }
        if (pts.isEmpty()) return@Canvas
        val path = Path().apply {
            moveTo(pts[0].x, pts[0].y)
            pts.drop(1).forEach { lineTo(it.x, it.y) }
            if (line.closed == true) close()
        }
        val measure = PathMeasure().apply { setPath(path, false) }
        val part = Path()
        measure.getSegment(0f, measure.length * progress.value, part, true)
        // Soft shadow under the line, then the line.
        drawPath(part, Color.Black.copy(alpha = 0.3f), style = Stroke((width + 3).dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(part, tint, style = Stroke(width.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}
