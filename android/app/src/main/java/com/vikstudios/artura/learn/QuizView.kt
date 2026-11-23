package com.vikstudios.artura.learn

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArcTopShape
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
import com.vikstudios.artura.core.zoomable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.services.Analytics
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** End-of-lesson quiz: one question at a time, with instant feedback. `onFinish` receives the number of correct answers. */
@Composable
fun QuizView(artwork: Artwork, onBack: () -> Unit, onFinish: (Int) -> Unit) {
    var index by rememberSaveable { mutableIntStateOf(0) }
    var selected by rememberSaveable { mutableStateOf<Int?>(null) }
    var score by rememberSaveable { mutableIntStateOf(0) }
    val shake = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val count = artwork.quiz.size
    if (count == 0) return
    val question = artwork.quiz[index.coerceIn(0, count - 1)]
    val isLast = index >= count - 1
    val isCorrect = selected == question.answer

    fun pick(i: Int) {
        if (selected != null) return
        Analytics.track("quiz_answer", mapOf(
            "artwork" to artwork.id, "question_index" to index, "question_count" to count,
            "chosen" to i, "correct_answer" to question.answer, "correct" to (i == question.answer),
        ))
        selected = i
        // The feedback panel slides in: a second, duller haptic.
        scope.launch { delay(250); Haptics.rigid() }
        if (i == question.answer) {
            score += 1
            Haptics.success()
        } else {
            Haptics.error()
            scope.launch {
                shake.animateTo(0f, keyframes {
                    durationMillis = 350
                    5f at 45
                    -5f at 105
                    5f at 165
                    -5f at 225
                    5f at 285
                })
            }
        }
    }

    fun advance() {
        Haptics.soft()
        if (isLast) onFinish(score) else {
            selected = null
            index += 1
        }
    }

    Box(Modifier.fillMaxSize().background(Palette.bg)) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 24.dp).padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                Modifier.fillMaxWidth().extendStart(12.dp).height(44.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier.size(44.dp).pressable(onClick = onBack),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, L("Back"), tint = Palette.ink, modifier = Modifier.size(34.dp))
                }
                ProgressTrack(
                    (index + if (selected == null) 0 else 1).toDouble() / count,
                    Modifier.weight(1f),
                )
            }

            AnimatedContent(
                targetState = index,
                transitionSpec = { (slideInHorizontally(tween(240)) { it } + fadeIn(tween(240))) togetherWith fadeOut(tween(200)) },
                label = "question",
            ) { i ->
                val q = artwork.quiz[i.coerceIn(0, count - 1)]
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TagPill(L("Question %@ of %@", "${i + 1}", "$count"))
                    Text(q.question, style = AType.titleSmall, color = Palette.ink)
                }
            }

            ArtImage(artwork.image, Modifier.fillMaxWidth().height(190.dp).clip(RoundedCornerShape(16.dp)).zoomable(artwork))

            Column(
                Modifier.fillMaxWidth().graphicsLayer { translationX = shake.value.dp.toPx() },
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                question.options.forEachIndexed { i, option ->
                    OptionButton(option, answered = selected != null, isAnswer = i == question.answer, isPicked = i == selected) { pick(i) }
                }
            }
            Spacer(Modifier.weight(1f))
        }

        AnimatedVisibility(
            visible = selected != null,
            enter = slideInVertically(tween(240)) { it },
            exit = slideOutVertically(tween(200)) { it },
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.mist, ArcTopShape)
                    .navigationBarsPadding()
                    .padding(horizontal = 24.dp)
                    .padding(top = 34.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(if (isCorrect) L("Good eye!") else L("Not quite"), style = figtree(17, FontWeight.SemiBold), color = Palette.ink)
                    Text(question.explanation, style = AType.small, color = Palette.ink)
                }
                PillButton(if (isLast) L("Finish quiz") else L("Next question")) { advance() }
            }
        }
    }
}

@Composable
private fun OptionButton(option: String, answered: Boolean, isAnswer: Boolean, isPicked: Boolean, onClick: () -> Unit) {
    val border = if (answered && isAnswer) Palette.green else if (answered && isPicked) Palette.red else Color.Transparent
    val fill = if (answered && isAnswer) Palette.greenSoft else if (answered && isPicked) Palette.redSoft else Palette.card
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .pressable(enabled = !answered, onClick = onClick)
            .clip(shape)
            .background(fill)
            .border(2.dp, border, shape)
            .padding(horizontal = 18.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            option, color = Palette.ink, modifier = Modifier.weight(1f),
            style = figtree(16, if (answered && (isAnswer || isPicked)) FontWeight.SemiBold else FontWeight.Medium),
        )
        Spacer(Modifier.width(8.dp))
        AnimatedVisibility(answered && (isAnswer || isPicked), enter = scaleIn(tween(160))) {
            if (isAnswer) CheckBadge(Palette.green)
            else Box(Modifier.size(28.dp).clip(CircleShape).background(Palette.red), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, null, tint = Color.White, modifier = Modifier.size(16.dp))
            }
        }
    }
}

/** Widens the element by `amount` on the leading side (SwiftUI `.padding(.leading, -amount)`). */
fun Modifier.extendStart(amount: androidx.compose.ui.unit.Dp): Modifier = this.then(
    Modifier.layout { measurable, constraints ->
        val extra = amount.roundToPx()
        val wide = if (constraints.hasBoundedWidth) constraints.copy(minWidth = constraints.minWidth + extra, maxWidth = constraints.maxWidth + extra) else constraints
        val placeable = measurable.measure(wide)
        val width = (placeable.width - extra).coerceAtLeast(0)
        layout(width, placeable.height) {
            placeable.placeRelative(-extra, 0)
        }
    }
)
