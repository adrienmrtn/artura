package com.vikstudios.artura.main

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArcHeaderShape
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.ProgressTrack
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.ContentStore
import com.vikstudios.artura.data.UserStore
import com.vikstudios.artura.games.GameHost
import com.vikstudios.artura.games.GameKind

@Composable
fun GamesView() {
    val user = LocalUser.current
    var game by remember { mutableStateOf<GameKind?>(null) }
    /** The daily challenge rotates through the four games. */
    val daily = GameKind.listed[(ContentStore.dayOrdinal() % GameKind.listed.size).toInt()]

    Column(Modifier.fillMaxSize().background(Palette.bg).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.fillMaxWidth().height(160.dp)) {
            ArtImage("ill_musee", Modifier.matchParentSize().clip(ArcHeaderShape), anchor = Offset(0.5f, 0.1f))
            Box(
                Modifier.padding(start = 16.dp, top = 60.dp).height(40.dp).clip(CircleShape).background(Color.White).padding(horizontal = 16.dp),
                contentAlignment = Alignment.Center,
            ) { Text(L("Games"), style = figtree(22, FontWeight.SemiBold), color = Palette.ink) }
        }

        Column(
            Modifier.padding(horizontal = 24.dp).offset(y = (-20).dp).padding(bottom = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            WeekCard(user)
            Box(Modifier.padding(vertical = 4.dp)) { TrainingButton { game = GameKind.Training } }
            Text(L("Or pick a game"), style = AType.heading, color = Palette.ink)
            GameKind.listed.forEachIndexed { i, kind ->
                GameRow(kind, kind == daily, Modifier.appearUp(0.06 * (i + 1))) { game = kind }
            }
        }
    }

    val shown = game
    FullScreenCover(visible = shown != null, onDismiss = { game = null }) {
        if (shown != null) GameHost(shown) { game = null }
    }
}

@Composable
private fun WeekCard(user: UserStore) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (user.streak == 0) L("Start your streak") else L("%@-day streak", "${user.streak}"),
                style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
            Spacer(Modifier.weight(1f))
            Text(if (user.playedToday) L("Done for today") else L("Play today to keep it"), style = AType.caption, color = Palette.muted)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            user.week.forEach { day ->
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(
                        Modifier.size(32.dp).clip(CircleShape).background(if (day.played) Palette.yellow else Color.White)
                            .border(2.dp, if (day.isToday && !day.played) Palette.blue else Color.Transparent, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (day.played) Icon(Icons.Rounded.Check, null, tint = Palette.ink, modifier = Modifier.size(16.dp))
                    }
                    Text(day.label, style = figtree(12, if (day.isToday) FontWeight.Bold else FontWeight.Normal),
                        color = if (day.isToday) Palette.ink else Palette.muted)
                }
            }
        }
    }
}

@Composable
private fun GameRow(kind: GameKind, isDaily: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().pressable(onClick = onClick).clip(RoundedCornerShape(16.dp)).background(Palette.card),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ArtImage(kind.image, Modifier.size(96.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            if (isDaily) TagPill(L("Daily challenge"))
            Text(kind.title, style = AType.cardTitle, color = Palette.ink)
            Text(kind.subtitle, style = AType.caption, color = Palette.muted)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.ink, modifier = Modifier.padding(end = 14.dp).size(22.dp))
    }
}

/** "Practice" button with today's counter; dimmed once the 30 questions are done. */
@Composable
fun TrainingButton(onClick: () -> Unit) {
    val user = LocalUser.current
    val goal = UserStore.TRAINING_DAILY_GOAL
    val caption = when {
        user.trainingFinished -> L("You've finished today's practice. Come back tomorrow!")
        user.trainingDoneToday == 0 -> L("%@ questions a day, all four games mixed.", "$goal")
        else -> L("%@ of %@ today · %@ to go", "${user.trainingDoneToday}", "$goal", "${user.trainingRemaining}")
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        PillButton(
            if (user.trainingFinished) L("Practice done") else if (user.trainingDoneToday == 0) L("Practice") else L("Resume practice"),
            Modifier.graphicsLayer { alpha = if (user.trainingFinished) 0.4f else 1f },
            enabled = !user.trainingFinished,
            onClick = onClick,
        )
        ProgressTrack(user.trainingDoneToday.toDouble() / goal)
        Text(caption, style = AType.caption, color = Palette.muted, textAlign = TextAlign.Center)
    }
}
