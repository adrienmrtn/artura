package com.vikstudios.artura.learn

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.rounded.ChangeHistory
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.OpenInFull
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.ProgressTrack
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.core.zoomable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.LessonBlock
import com.vikstudios.artura.services.Analytics
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Icon of an interactive block (SF Symbol on iOS: scope, hand.tap.fill, triangle, paintpalette.fill, magnifyingglass). */
val LessonBlock.interactiveIcon: ImageVector
    get() = when (type) {
        "tour" -> Icons.Rounded.GpsFixed
        "find" -> Icons.Rounded.TouchApp
        "lines" -> Icons.Rounded.ChangeHistory
        "palette" -> Icons.Rounded.Palette
        else -> Icons.Rounded.Search
    }

/**
 * Reads a lesson block by block: each tap on "Continue" reveals the next block and scrolls it to the
 * center of the screen. In the app: `freeTaps` limits a free reader (null = no limit) and `onBlocked`
 * opens the paywall. In the onboarding: `pill`, `blocks` (the preview), `finishTitle`, `onSkip`.
 */
@Composable
fun LessonView(
    artwork: Artwork,
    onBack: () -> Unit,
    onFinish: () -> Unit,
    freeTaps: Int? = null,
    onBlocked: () -> Unit = {},
    pill: String? = null,
    blocks: List<LessonBlock>? = null,
    finishTitle: String? = null,
    onSkip: (() -> Unit)? = null,
    /** Called after each "Continue" that reveals a block, with the number of taps so far. */
    onContinue: ((Int) -> Unit)? = null,
) {
    val pillText = pill ?: L("Lesson")
    val finishText = finishTitle ?: L("Take the quiz")
    val lesson = blocks ?: artwork.lesson
    val total = lesson.size

    var revealed by rememberSaveable { mutableIntStateOf(0) }
    var taps by rememberSaveable { mutableIntStateOf(0) }
    /** Interactive block opened full screen on the painting. */
    var studio by remember { mutableStateOf<Int?>(null) }
    val isDone = revealed >= total

    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    /** Top and height (px) of each revealed block, in the scrolling column. */
    val positions = remember { mutableStateMapOf<Int, Pair<Float, Int>>() }
    var viewport by remember { mutableIntStateOf(0) }

    /** Records where the reader is in the lesson (blocks read and percentage). */
    fun trackLesson(name: String, block: Int) {
        val percent = if (total > 0) (block.toDouble() / total * 100).roundToInt() else 100
        Analytics.track(name, mapOf("artwork" to artwork.id, "context" to pillText, "block" to block, "blocks" to total, "percent" to percent))
    }

    fun open(index: Int) {
        Haptics.press()
        studio = index
    }

    val revealedNow by rememberUpdatedState(revealed)
    LaunchedEffect(Unit) { trackLesson("lesson_opened", 0) }
    DisposableEffect(Unit) { onDispose { trackLesson("lesson_closed", revealedNow) } }
    var firstProgress by remember { mutableStateOf(true) }
    LaunchedEffect(revealed) {
        if (firstProgress) { firstProgress = false; return@LaunchedEffect }
        trackLesson("lesson_progress", revealed)
    }

    // The block just revealed moves to the center right away.
    LaunchedEffect(revealed) {
        if (revealed <= 0) return@LaunchedEffect
        val index = revealed - 1
        repeat(20) {
            val p = positions[index]
            if (p != null) {
                val target = (p.first + p.second / 2f - viewport / 2f).roundToInt().coerceIn(0, scroll.maxValue)
                scroll.animateScrollTo(target, tween(220))
                return@LaunchedEffect
            }
            delay(16)
        }
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(
                Modifier.fillMaxWidth().padding(start = 12.dp, end = 24.dp).height(44.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier.size(44.dp).pressable { onBack() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, L("Back"), tint = Palette.ink, modifier = Modifier.size(34.dp))
                }
                ProgressTrack((revealed + 1).toDouble() / (total + 1), Modifier.weight(1f))
                if (onSkip != null) {
                    Box(Modifier.height(44.dp).pressable { Haptics.tap(); onSkip() }, contentAlignment = Alignment.Center) {
                        Text(L("Skip"), style = figtree(15, FontWeight.SemiBold), color = Palette.muted)
                    }
                } else {
                    Text("${revealed + 1} / ${total + 1}", style = figtree(14, FontWeight.Medium), color = Palette.muted)
                }
            }

            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .onGloballyPositioned { viewport = it.size.height }
                    .verticalScroll(scroll)
                    .padding(horizontal = 24.dp)
                    .padding(top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TagPill(pillText)
                    Text(artwork.title, style = figtree(28, FontWeight.SemiBold), color = Palette.ink)
                    Text("${artwork.meta} · ${artwork.museum}", style = AType.small, color = Palette.muted)
                }
                ArtImage(artwork.image, Modifier.fillMaxWidth().height(270.dp).clip(RoundedCornerShape(16.dp)).zoomable(artwork))
                artwork.credit?.let { Text(it, style = figtree(11), color = Palette.muted) }

                lesson.take(revealed).forEachIndexed { index, block ->
                    Box(
                        Modifier.fillMaxWidth().onGloballyPositioned {
                            positions[index] = it.positionInParent().y to it.size.height
                        }
                    ) {
                        FadeIn(index) {
                            if (block.isInteractive) InteractiveCard(artwork, block) { open(index) }
                            else BlockView(artwork, block)
                        }
                    }
                }
                // Bottom margin: lets the last block scroll up to the center of the screen.
                Spacer(Modifier.height(340.dp))
            }

            PillButton(
                if (isDone) finishText else L("Continue"),
                Modifier.padding(horizontal = 24.dp).padding(bottom = 16.dp),
            ) {
                if (isDone) {
                    Haptics.success()
                    trackLesson("lesson_finished", total)
                    onFinish()
                } else {
                    taps += 1
                    if (freeTaps != null && taps > freeTaps) {
                        trackLesson("lesson_blocked", revealed)
                        // The lesson stops here for a free reader.
                        Haptics.press()
                        onBlocked()
                        return@PillButton
                    }
                    Haptics.soft()
                    val index = revealed
                    revealed += 1
                    // An interactive block opens on the painting right away.
                    if (index in lesson.indices && lesson[index].isInteractive) {
                        scope.launch { delay(250); open(index) }
                    }
                    onContinue?.invoke(taps)
                }
            }
        }

        val shown = studio
        AnimatedVisibility(
            visible = shown != null && shown in lesson.indices,
            enter = fadeIn(tween(300)),
            exit = fadeOut(tween(300)),
        ) {
            val last = remember { mutableStateOf(shown ?: 0) }
            if (shown != null) last.value = shown
            androidx.compose.runtime.key(last.value) {
                PaintingStudio(artwork = artwork, block = lesson[last.value.coerceIn(0, maxOf(0, lesson.size - 1))]) { studio = null }
            }
        }
    }
}

/** A revealed block fades in (0.15 s). */
@Composable
private fun FadeIn(key: Int, content: @Composable () -> Unit) {
    val visible = remember(key) { androidx.compose.animation.core.MutableTransitionState(false).apply { targetState = true } }
    AnimatedVisibility(visibleState = visible, enter = fadeIn(tween(150))) { content() }
}

/** Within the lesson, an interactive block leaves a card you can reopen. */
@Composable
private fun InteractiveCard(artwork: Artwork, block: LessonBlock, onOpen: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .pressable(onClick = onOpen)
            .clip(RoundedCornerShape(16.dp))
            .background(hexColor(0x1B1917))
            .padding(10.dp)
            .padding(end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(72.dp).clip(RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            ArtImage(artwork.image, Modifier.matchParentSize(), zoom = 1.6f, anchor = artwork.focusPoint, small = true)
            Box(Modifier.size(34.dp).clip(CircleShape).background(Palette.blue), contentAlignment = Alignment.Center) {
                Icon(block.interactiveIcon, null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(block.interactiveTitle, style = AType.cardTitle, color = Color.White)
            Text(L("Tap to reopen the painting"), style = AType.caption, color = Color.White.copy(alpha = 0.75f))
        }
        Icon(Icons.Rounded.OpenInFull, null, tint = Color.White, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun BlockView(artwork: Artwork, block: LessonBlock) {
    when (block.type) {
        "image" -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ArtImage(
                artwork.image,
                Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(16.dp)).zoomable(artwork),
                zoom = (block.zoom ?: 2.0).toFloat(), anchor = block.unitAnchor,
            )
            block.caption?.let { Text(it, style = AType.caption, color = Palette.muted) }
        }
        "key" -> Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.mist).padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(L("Key takeaway"), style = figtree(12, FontWeight.SemiBold), color = Palette.blueText)
            Text(block.text ?: "", style = AType.bodyStrong, color = Palette.ink)
        }
        "fact" -> Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.yellow.copy(alpha = 0.28f))
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Lightbulb, null, tint = Palette.ink, modifier = Modifier.size(14.dp))
                Text(L("Did you know?"), style = figtree(12, FontWeight.SemiBold), color = Palette.ink)
            }
            Text(block.text ?: "", style = figtree(16), color = Palette.ink)
        }
        else -> Text(block.text ?: "", style = figtree(17).copy(lineHeight = 26.sp), color = Palette.ink)
    }
}
