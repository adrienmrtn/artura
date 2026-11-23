package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.figtree

/** Header of a game: "Round 2 of 5" on the left, the points on the right (they roll like `.numericText()`). */
@Composable
fun RoundHeader(tag: String, score: Int) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        TagPill(tag)
        Spacer(Modifier.weight(1f))
        AnimatedContent(
            targetState = score,
            transitionSpec = { (slideInVertically { it / 2 } + fadeIn()) togetherWith fadeOut() },
            label = "points",
        ) { s ->
            Text(if (s == 1) L("1 point") else L("%@ points", "$s"), style = figtree(14, FontWeight.SemiBold), color = Palette.muted)
        }
    }
}

/** Fill and border of an answer once the question is answered: green for the right one, red for a wrong pick. */
fun answerColors(answered: Boolean, isAnswer: Boolean, isPicked: Boolean, idle: Color = Palette.card): Pair<Color, Color> = when {
    answered && isAnswer -> Palette.greenSoft to Palette.green
    answered && isPicked -> Palette.redSoft to Palette.red
    else -> idle to Color.Transparent
}

fun Modifier.answerCard(fill: Color, border: Color, radius: Dp = 12.dp, borderWidth: Dp = 2.dp): Modifier {
    val shape = RoundedCornerShape(radius)
    return this.clip(shape).background(fill).border(borderWidth, border, shape)
}

/** The "Next" / "See my score" button sliding in once a question is answered (`.opacity + .offset(y: 16)`). */
val buttonEnter: EnterTransition get() = fadeIn(Anim.gentle()) + slideInVertically(Anim.gentle()) { 48 }
