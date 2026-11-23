package com.vikstudios.artura.review

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.ProgressTrack
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.main.ResultView

/** Plays a deck of questions one by one, then shows the score. Present it in a `FullScreenCover`. */
@Composable
fun ReviewSessionView(deck: ReviewDeck, onDismiss: () -> Unit) {
    val user = LocalUser.current
    var index by rememberSaveable { mutableIntStateOf(0) }
    var picked by rememberSaveable { mutableStateOf<String?>(null) }
    var score by rememberSaveable { mutableIntStateOf(0) }
    var finished by rememberSaveable { mutableStateOf(false) }
    val count = deck.cards.size
    val isLast = index >= count - 1

    LaunchedEffect(Unit) { Haptics.soft() }

    fun advance() {
        Haptics.tap()
        if (isLast) {
            // A finished session keeps the streak alive; the daily review is marked done.
            if (deck.daily) user.completeReview() else user.markPlayedToday()
            finished = true
        } else {
            picked = null
            index += 1
        }
    }

    AnimatedContent(
        targetState = finished || count == 0,
        transitionSpec = { fadeIn(tween(240)) togetherWith fadeOut(tween(240)) },
        modifier = Modifier.fillMaxSize().background(Palette.bg),
        label = "session",
    ) { done ->
        if (done) {
            ResultView(
                title = if (score == count) L("Perfect score!") else if (score * 2 >= count) L("Nicely done") else L("Keep at it"),
                detail = L("%@ of %@ correct", "$score", "$count"),
                celebrate = score * 2 >= count,
                onDone = onDismiss,
            )
        } else {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                // Header
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(
                        Modifier.size(44.dp).clip(CircleShape).background(Palette.card).pressable(onClick = onDismiss)
                            .semantics { contentDescription = L("Quit the session") },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.Close, null, tint = Palette.ink, modifier = Modifier.size(20.dp)) }
                    ProgressTrack((index + if (picked == null) 0 else 1).toDouble() / maxOf(1, count), Modifier.weight(1f))
                    Text("${index + 1} / $count", style = figtree(14, FontWeight.Medium), color = Palette.muted)
                }
                AnimatedContent(
                    targetState = index,
                    transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(150)) },
                    modifier = Modifier.weight(1f),
                    label = "card",
                ) { i ->
                    val card = deck.cards[i.coerceIn(0, count - 1)]
                    Question(card, picked, onPick = { choice ->
                        if (picked == null) {
                            picked = choice.id
                            if (choice.id == card.correct) { score += 1; Haptics.success() } else Haptics.error()
                        }
                    })
                }
                val a by animateFloatAsState(if (picked == null) 0.4f else 1f, tween(160), label = "next")
                PillButton(
                    if (isLast) L("See my score") else L("Next"),
                    Modifier.padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp).graphicsLayer { alpha = a },
                    enabled = picked != null,
                ) { advance() }
            }
        }
    }
}

@Composable
private fun Question(card: ReviewCard, picked: String?, onPick: (ReviewCard.Choice) -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TagPill(card.kind)
        Text(card.prompt, style = AType.titleSmall, color = Palette.ink)
        card.image?.let {
            ArtImage(it, Modifier.fillMaxWidth().height(if (card.statement == null) 200.dp else 150.dp).clip(RoundedCornerShape(20.dp)),
                anchor = card.anchor)
        }
        card.statement?.let { Text(it, style = figtree(19, FontWeight.SemiBold), color = Palette.ink) }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            card.choices.forEach { choice -> ChoiceButton(choice, card, picked) { onPick(choice) } }
        }
        AnimatedVisibility(picked != null, enter = fadeIn(tween(150))) {
            Text(
                card.explanation, style = AType.small, color = Palette.ink,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                    .background(if (picked == card.correct) Palette.greenSoft else Palette.redSoft).padding(12.dp),
            )
        }
    }
}

@Composable
private fun ChoiceButton(choice: ReviewCard.Choice, card: ReviewCard, picked: String?, onClick: () -> Unit) {
    val answered = picked != null
    val isAnswer = choice.id == card.correct
    val isPicked = choice.id == picked
    val fill = if (answered && isAnswer) Palette.greenSoft else if (answered && isPicked) Palette.redSoft else Color.White
    val border = if (answered && isAnswer) Palette.green else if (answered && isPicked) Palette.red else Palette.line
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .pressable(enabled = !answered, onClick = onClick)
            .clip(shape)
            .background(fill)
            .border(if (answered && (isAnswer || isPicked)) 2.dp else 1.dp, border, shape)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(choice.title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(8.dp))
        if (answered && isAnswer) CheckBadge(Palette.green, 24.dp)
    }
}
