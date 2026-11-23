package com.vikstudios.artura.core

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.services.Analytics
import kotlinx.coroutines.launch

// Full-screen viewer for a painting: pinch to zoom, double tap to zoom in and out, drag to move.

/** What the viewer shows: the picture, and a lighter version to display while the large one loads. */
data class ZoomTarget(val image: String, val placeholder: String? = null, val title: String? = null) {
    constructor(artwork: Artwork) : this(artwork.canvasImage, artwork.image, artwork.title)
}

/** A tap opens the painting full screen, where it can be zoomed (pinch, double tap, drag). */
fun Modifier.zoomable(artwork: Artwork): Modifier = composed {
    var shown by remember { mutableStateOf<ZoomTarget?>(null) }
    val target = shown
    FullScreenCover(visible = target != null, onDismiss = { shown = null }) {
        if (target != null) ZoomViewer(target) { shown = null }
    }
    Modifier
        .semantics { contentDescription = L("Opens the painting full screen") }
        .pointerInput(artwork.id) {
            detectTapGestures(onTap = {
                Haptics.tap()
                shown = ZoomTarget(artwork)
            })
        }
}

private const val MAX_ZOOM = 6f

/** Full-screen viewer; present it with `FullScreenCover`. */
@Composable
fun ZoomViewer(target: ZoomTarget, onClose: () -> Unit) {
    LaunchedEffect(Unit) { Analytics.track("artwork_zoom_opened", mapOf("image" to target.image)) }
    val scale = remember { Animatable(1f) }
    val offset = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    val scope = rememberCoroutineScope()

    BoxWithConstraints(
        Modifier.fillMaxSize().background(Color.Black).semantics { contentDescription = target.title ?: L("Painting") }
    ) {
        val w = constraints.maxWidth.toFloat()
        val h = constraints.maxHeight.toFloat()

        /** Keeps the picture on screen: no empty border beyond its edges at zoom 1. */
        fun clamp(o: Offset, s: Float): Offset {
            val mx = (w * (s - 1)) / 2
            val my = (h * (s - 1)) / 2
            return Offset(o.x.coerceIn(-mx, mx), o.y.coerceIn(-my, my))
        }

        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTapGestures(onDoubleTap = { point ->
                        scope.launch {
                            if (scale.value > 1.01f) {
                                launch { scale.animateTo(1f, tween(300)) }
                                offset.animateTo(Offset.Zero, tween(300))
                            } else {
                                // Zoom in on the point that was tapped.
                                val s = 3f
                                val center = Offset(w / 2, h / 2)
                                val to = clamp((center - point) * s, s)
                                launch { scale.animateTo(s, tween(300)) }
                                offset.animateTo(to, tween(300))
                            }
                        }
                        Haptics.soft()
                    })
                }
                .pointerInput(Unit) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        do {
                            val event = awaitPointerEvent()
                            val zoom = event.calculateZoom()
                            val pan = event.calculatePan()
                            val pinching = event.changes.count { it.pressed } > 1
                            if (pinching || scale.value > 1.01f) {
                                val centroid = event.calculateCentroid()
                                val old = scale.value
                                val s = (old * zoom).coerceIn(1f, MAX_ZOOM)
                                // Zoom around the fingers.
                                val anchor = if (centroid == Offset.Unspecified) Offset.Zero else centroid - Offset(w / 2, h / 2)
                                val o = (offset.value - anchor) * (s / old) + anchor + pan
                                scope.launch {
                                    scale.snapTo(s)
                                    offset.snapTo(clamp(o, s))
                                }
                                event.changes.forEach { if (it.positionChanged()) it.consume() }
                            }
                        } while (event.changes.any { it.pressed })
                    }
                }
                .graphicsLayer {
                    scaleX = scale.value
                    scaleY = scale.value
                    translationX = offset.value.x
                    translationY = offset.value.y
                },
            contentAlignment = Alignment.Center,
        ) {
            // What is already at hand at once, then the large picture when it arrives.
            target.placeholder?.let { ViewerPicture(it) }
            ViewerPicture(target.image, loading = target.placeholder == null)
        }

        Box(
            Modifier
                .align(Alignment.TopEnd)
                .statusBarsPadding()
                .padding(end = 16.dp, top = 8.dp)
                .size(44.dp)
                .background(Color.White.copy(alpha = 0.18f), CircleShape)
                .pressable { onClose() },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Close, L("Close"), tint = Color.White, modifier = Modifier.size(20.dp))
        }
    }
}

/** A picture fitted to the screen, on a transparent background (bundled drawable or catalog address). */
@Composable
private fun ViewerPicture(name: String, loading: Boolean = false) {
    if (name.startsWith("http")) {
        val context = LocalContext.current
        var done by remember(name) { mutableStateOf(false) }
        if (loading && !done) CircularProgressIndicator(color = Color.White, strokeWidth = 3.dp, modifier = Modifier.size(28.dp))
        AsyncImage(
            model = remember(name) { ImageRequest.Builder(context).data(name).crossfade(200).build() },
            contentDescription = null,
            contentScale = ContentScale.Fit,
            onSuccess = { done = true },
            modifier = Modifier.fillMaxSize(),
        )
    } else {
        val id = drawableId(name)
        if (id != 0) Image(painterResource(id), null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
    }
}
