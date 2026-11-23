package com.vikstudios.artura.core

import android.annotation.SuppressLint
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
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
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.delay

// MARK: - Press feedback

/** Clickable without ripple, shrinking slightly while pressed, with a light haptic (iOS `.pressable`). */
@SuppressLint("ModifierFactoryUnreferencedReceiver")
fun Modifier.pressable(
    scale: Float = 0.97f,
    enabled: Boolean = true,
    haptic: Boolean = true,
    onClick: () -> Unit,
): Modifier = composedPressable(scale, enabled, haptic, onClick)

@Composable
private fun pressState(source: MutableInteractionSource, haptic: () -> Unit): Boolean {
    val pressed by source.collectIsPressedAsState()
    LaunchedEffect(pressed) { if (pressed) haptic() }
    return pressed
}

private fun Modifier.composedPressable(scale: Float, enabled: Boolean, haptic: Boolean, onClick: () -> Unit): Modifier =
    composed {
        val source = remember { MutableInteractionSource() }
        val pressed = pressState(source) { if (haptic) Haptics.tap() }
        val s by animateFloatAsState(if (pressed) scale else 1f, Anim.snappy(), label = "press")
        Modifier
            .graphicsLayer { scaleX = s; scaleY = s }
            .clickable(interactionSource = source, indication = null, enabled = enabled, onClick = onClick)
    }

// MARK: - Buttons

enum class PillStyle(val fill: Color, val lip: Color, val foreground: Color) {
    Primary(Palette.blue, Palette.blueDark, Color.White),
    Secondary(Palette.card, Palette.lip, Palette.ink),
    Dark(Palette.ink, Color.Black, Color.White),
}

/** Pill button with a bottom lip: it presses down on touch, with haptic feedback. */
@Composable
fun PillButton(
    title: String,
    modifier: Modifier = Modifier,
    style: PillStyle = PillStyle.Primary,
    fill: Color = style.fill,
    lip: Color = style.lip,
    foreground: Color = style.foreground,
    height: Dp = 56.dp,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    PillButton(modifier, style, fill, lip, height, enabled, onClick) {
        Text(title, style = AType.bodyStrong, color = foreground, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
fun PillButton(
    modifier: Modifier = Modifier,
    style: PillStyle = PillStyle.Primary,
    fill: Color = style.fill,
    lip: Color = style.lip,
    height: Dp = 56.dp,
    enabled: Boolean = true,
    onClick: () -> Unit,
    content: @Composable RowScope.() -> Unit,
) {
    val source = remember { MutableInteractionSource() }
    val pressed = pressState(source) { Haptics.press() }
    val y by animateDpAsState(if (pressed) 3.dp else 0.dp, Anim.snappy(), label = "pill")
    Box(
        modifier
            .fillMaxWidth()
            .height(height + 3.dp)
            .clickable(interactionSource = source, indication = null, enabled = enabled, onClick = onClick)
    ) {
        Box(Modifier.fillMaxWidth().height(height).offset(y = 3.dp).clip(CircleShape).background(lip))
        Row(
            Modifier.fillMaxWidth().height(height).offset(y = y).clip(CircleShape).background(fill).padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
fun TextLinkButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier.fillMaxWidth().height(48.dp).pressable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(title, style = figtree(15, FontWeight.SemiBold), color = Palette.blueText, textAlign = TextAlign.Center)
    }
}

// MARK: - Small elements

@Composable
fun TagPill(text: String, fill: Color = Palette.yellow, foreground: Color = Palette.ink) {
    Text(
        text, style = figtree(13, FontWeight.SemiBold), color = foreground,
        modifier = Modifier.clip(CircleShape).background(fill).padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
fun ProgressTrack(value: Double, modifier: Modifier = Modifier) {
    val v by animateFloatAsState(value.toFloat().coerceIn(0f, 1f), Anim.gentle(), label = "track")
    BoxWithConstraints(modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Palette.line)) {
        Box(Modifier.width(maxOf(8.dp, maxWidth * v)).height(8.dp).clip(CircleShape).background(Palette.blue))
    }
}

@Composable
fun CheckBadge(color: Color = Palette.blue, size: Dp = 28.dp) {
    Box(Modifier.size(size).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
        Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(size * 0.6f))
    }
}

@Composable
fun StreakChip(days: Int) {
    Row(
        Modifier.height(36.dp).clip(CircleShape).background(Color.White).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Rounded.LocalFireDepartment, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
        Text(if (days == 1) L("1 day") else L("%@ days", "$days"), style = figtree(14, FontWeight.SemiBold), color = Palette.ink)
    }
}

// MARK: - Selectable cards

/** Selectable answer row (onboarding questions). */
@Composable
fun OptionRow(title: String, selected: Boolean, subtitle: String? = null, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .pressable { Haptics.selection(); onClick() }
            .clip(shape)
            .background(if (selected) Palette.mistLight else Palette.card)
            .border(2.dp, if (selected) Palette.blue else Color.Transparent, shape)
            .padding(horizontal = 18.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = AType.bodyStrong, color = Palette.ink)
            if (subtitle != null) Text(subtitle, style = AType.caption, color = Palette.muted)
        }
        Spacer(Modifier.width(8.dp))
        AnimatedVisibility(selected, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) { CheckBadge() }
    }
}

// MARK: - Images

/** Drawable id of a bundled image ("art_nuit", "ill_hero"…), 0 if there is none. */
@SuppressLint("DiscouragedApi")
@Composable
fun drawableId(name: String): Int {
    val context = LocalContext.current
    return remember(name) { context.resources.getIdentifier(name, "drawable", context.packageName) }
}

/**
 * Artwork or illustration image, filled and cropped, with optional zoom on a point (0…1).
 * `name` is a bundled drawable name or an https address of the online catalog.
 */
@Composable
fun ArtImage(
    name: String,
    modifier: Modifier = Modifier,
    zoom: Float = 1f,
    anchor: Offset = Offset(0.5f, 0.5f),
    contentScale: ContentScale = ContentScale.Crop,
    small: Boolean = false,
) {
    Box(modifier.clipToBounds().background(Palette.card)) {
        val inner = Modifier.fillMaxSize().graphicsLayer {
            scaleX = zoom; scaleY = zoom
            transformOrigin = TransformOrigin(anchor.x, anchor.y)
        }
        if (name.startsWith("http")) {
            val url = if (small && name.endsWith("/large.jpg")) name.removeSuffix("large.jpg") + "thumb.jpg" else name
            RemoteImage(url, inner, contentScale)
        } else {
            val id = drawableId(name)
            if (id != 0) Image(painterResource(id), null, inner, contentScale = contentScale)
        }
    }
}

/** An image of the online catalog: a soft tint, then the picture fades in (memory + disk cache). */
@Composable
fun RemoteImage(url: String, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Crop) {
    val context = LocalContext.current
    AsyncImage(
        model = remember(url) { ImageRequest.Builder(context).data(url).crossfade(250).build() },
        contentDescription = null,
        modifier = modifier,
        contentScale = contentScale,
    )
}

// MARK: - Sky header (app screens)

@Composable
fun SkyHeader(height: Dp = 196.dp, content: @Composable () -> Unit) {
    val drift by rememberInfiniteTransition(label = "sky").animateFloat(
        0f, 1f, infiniteRepeatable(tween(4000), RepeatMode.Reverse), label = "drift")
    Box(Modifier.fillMaxWidth().height(height).clip(ArcHeaderShape).background(Palette.sky)) {
        Box(Modifier.offset(x = (244 + 14 * drift).dp, y = 52.dp).size(70.dp, 26.dp).clip(CircleShape).background(Palette.skyLight))
        Box(Modifier.offset(x = (-30).dp, y = height - 64.dp).size(120.dp).clip(CircleShape).background(Palette.cloud))
        Box(Modifier.offset(x = 290.dp, y = height - 58.dp).size(110.dp).clip(CircleShape).background(Palette.cloud))
        Box(Modifier.offset(x = 350.dp, y = height - 76.dp).size(90.dp).clip(CircleShape).background(Palette.cloud))
        content()
    }
}

// MARK: - Staggered appearance

/** Fades the element in from below, with a delay (for staggered reveals). */
fun Modifier.appearUp(delay: Double = 0.0): Modifier = composed {
    var shown by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay((delay * 500).toLong())
        shown = true
    }
    val a by animateFloatAsState(if (shown) 1f else 0f, tween(200), label = "appear")
    Modifier.graphicsLayer { alpha = a; translationY = (1 - a) * 6.dp.toPx() }
}
