package com.vikstudios.artura.app

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.zIndex
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.Palette

/**
 * Full-screen covers, the equivalent of SwiftUI's `.fullScreenCover`: a screen slides up over the whole
 * app (tab bar included) and the system back gesture closes it. Covers can be stacked.
 *
 *     FullScreenCover(visible = open, onDismiss = { open = false }) { LessonScreen(...) }
 */
class CoverHost {
    class Entry(val key: Any) {
        var content by mutableStateOf<@Composable () -> Unit>({})
        var onDismiss by mutableStateOf({})
        var dismissable by mutableStateOf(true)
        var transparent by mutableStateOf(false)
        val state = MutableTransitionState(false)
        var removing = false
    }

    val entries = mutableStateListOf<Entry>()
}

val LocalCoverHost = staticCompositionLocalOf<CoverHost> { error("CoverHost not provided") }

/**
 * Shows `content` full screen while `visible` is true. `dismissable = false` ignores the back gesture
 * (`.interactiveDismissDisabled()` on iOS). `transparent = true` lets the screen below show through
 * (for content that draws its own backdrop).
 */
@Composable
fun FullScreenCover(
    visible: Boolean,
    onDismiss: () -> Unit,
    dismissable: Boolean = true,
    transparent: Boolean = false,
    content: @Composable () -> Unit,
) {
    val host = LocalCoverHost.current
    val entry = remember { CoverHost.Entry(Any()) }
    SideEffect {
        entry.content = content
        entry.onDismiss = onDismiss
        entry.dismissable = dismissable
        entry.transparent = transparent
    }
    LaunchedEffect(visible) {
        if (visible) {
            entry.removing = false
            if (!host.entries.contains(entry)) host.entries.add(entry)
            entry.state.targetState = true
        } else {
            entry.state.targetState = false
            entry.removing = true
        }
    }
    DisposableEffect(Unit) {
        onDispose { host.entries.remove(entry) }
    }
}

/** Draws the open covers above the app. Placed once, at the root. */
@Composable
fun CoverLayer(host: CoverHost) {
    host.entries.forEachIndexed { index, entry ->
        val isTop = index == host.entries.lastIndex
        BackHandler(enabled = isTop && entry.state.targetState) { if (entry.dismissable) entry.onDismiss() }
        LaunchedEffect(entry.state.isIdle, entry.state.currentState) {
            if (entry.removing && entry.state.isIdle && !entry.state.currentState) host.entries.remove(entry)
        }
        AnimatedVisibility(
            visibleState = entry.state,
            enter = slideInVertically(Anim.glide()) { it } + fadeIn(Anim.gentle()),
            exit = slideOutVertically(Anim.gentle()) { it } + fadeOut(Anim.gentle()),
            modifier = Modifier.zIndex(10f + index),
        ) {
            Box(
                Modifier
                    .fillMaxSize()
                    .then(if (entry.transparent) Modifier else Modifier.background(Palette.bg))
                    // Touches never reach the screen below.
                    .clickable(remember { MutableInteractionSource() }, null) {}
            ) {
                entry.content()
            }
        }
    }
}

/**
 * The last non-null value of `value`: lets a cover keep showing its item while it slides away.
 *
 *     val shown = rememberLastNonNull(selected)
 *     FullScreenCover(visible = selected != null, onDismiss = { selected = null }) {
 *         shown?.let { CourseFlow(it) { selected = null } }
 *     }
 */
@Composable
fun <T> rememberLastNonNull(value: T?): T? {
    val last = remember { mutableStateOf(value) }
    if (value != null) last.value = value
    return last.value
}
