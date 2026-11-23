package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.main.ResultView

enum class GameKind {
    Zoom, Chronology, Palette, TrueFalse, Training;

    val title: String
        get() = when (this) {
            Zoom -> L("Mystery Zoom")
            Chronology -> L("Timeline")
            Palette -> L("Palette")
            TrueFalse -> L("True or False")
            Training -> L("Practice")
        }

    val subtitle: String
        get() = when (this) {
            Zoom -> L("Guess the artwork from a detail · 1 min")
            Chronology -> L("Put 4 artworks in date order · 2 min")
            Palette -> L("Match the painting's colors · 1 min")
            TrueFalse -> L("Studio stories · 1 min")
            Training -> L("All four question types, mixed")
        }

    val image: String
        get() = when (this) {
            Zoom -> "ill_zoom"
            Chronology -> "ill_chrono"
            Palette -> "ill_palette"
            TrueFalse -> "ill_vraifaux"
            Training -> "ill_hero"
        }

    companion object {
        /** The four games shown in the list (practice has its own button). */
        val listed = listOf(Zoom, Chronology, Palette, TrueFalse)
    }
}

/** Shared wrapper for the games: top bar, the game itself, end screen. Shown in a FullScreenCover. */
@Composable
fun GameHost(kind: GameKind, onDismiss: () -> Unit) {
    val user = LocalUser.current
    var result by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var round by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) { Haptics.soft() }

    val finish: (Int, Int) -> Unit = { score, total ->
        Haptics.press()
        user.recordGame(won = score * 2 >= total)
        result = score to total
    }

    AnimatedContent(
        targetState = result,
        transitionSpec = { fadeIn(Anim.gentle()) togetherWith fadeOut(Anim.gentle()) },
        modifier = Modifier.fillMaxSize().background(Palette.bg),
        label = "game",
    ) { r ->
        if (r != null) {
            val (score, total) = r
            val trainingDone = kind == GameKind.Training && user.trainingFinished
            ResultView(
                title = when {
                    trainingDone -> L("You've finished today's practice!")
                    score == total -> L("Perfect score!")
                    score * 2 >= total -> L("Nicely done")
                    else -> L("Try again?")
                },
                detail = if (trainingDone) L("%@ of %@ · come back tomorrow for 30 new questions", "$score", "$total")
                else L("%@ of %@", "$score", "$total"),
                celebrate = trainingDone || score * 2 >= total,
                onReplay = if (kind == GameKind.Training) null else ({
                    Haptics.tap()
                    result = null
                    round++
                }),
                onDone = onDismiss,
            )
        } else {
            Column(Modifier.fillMaxSize().background(Palette.bg).statusBarsPadding().navigationBarsPadding()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier.size(44.dp).clip(CircleShape).background(Palette.card).pressable { onDismiss() },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.Close, L("Quit the game"), tint = Palette.ink, modifier = Modifier.size(20.dp)) }
                    Spacer(Modifier.weight(1f))
                    Text(kind.title, style = figtree(17, FontWeight.SemiBold), color = Palette.ink)
                    Spacer(Modifier.weight(1f))
                    Spacer(Modifier.size(44.dp))
                }
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    key(round) {
                        when (kind) {
                            GameKind.Zoom -> ZoomGame(finish)
                            GameKind.Chronology -> ChronologyGame(finish)
                            GameKind.Palette -> PaletteGame(finish)
                            GameKind.TrueFalse -> TrueFalseGame(finish)
                            GameKind.Training -> TrainingGame(finish)
                        }
                    }
                }
            }
        }
    }
}
