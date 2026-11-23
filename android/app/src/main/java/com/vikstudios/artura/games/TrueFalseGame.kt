package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.hexColor
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.Fact
import kotlinx.coroutines.launch
import kotlin.math.abs

/** True or False: a card to swipe right (true) or left (false). */
@Composable
fun TrueFalseGame(onFinish: (Int, Int) -> Unit) {
    val content = LocalContent.current
    val deck = remember { content.allFacts.shuffled().take(8) }
    var index by remember { mutableIntStateOf(0) }
    var answer by remember { mutableStateOf<Boolean?>(null) }
    var score by remember { mutableIntStateOf(0) }
    var armed by remember { mutableStateOf(false) }
    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    val scope = rememberCoroutineScope()
    val threshold = with(LocalDensity.current) { 90.dp.toPx() }
    val card = deck.getOrNull(index)

    fun respond(value: Boolean) {
        val c = card ?: return
        if (answer != null) return
        armed = false
        answer = value
        scope.launch { drag.animateTo(Offset.Zero, Anim.bouncy()) }
        if (value == c.first.isTrue) { score++; Haptics.success() } else Haptics.error()
    }

    fun advance() {
        if (index >= deck.size - 1) {
            onFinish(score, deck.size)
        } else {
            Haptics.tap()
            answer = null
            index++
        }
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (card == null) return@Column
        RoundHeader(L("Card %@ of %@", "${index + 1}", "${deck.size}"), score)

        Box(Modifier.fillMaxWidth().heightIn(max = 430.dp).weight(1f, fill = false)) {
            if (index + 1 < deck.size) {
                Box(Modifier.matchParentSize().graphicsLayer { scaleX = 0.94f; scaleY = 0.94f; translationY = 14.dp.toPx() }
                    .clip(RoundedCornerShape(24.dp)).background(Palette.line))
            }
            AnimatedContent(
                targetState = index,
                transitionSpec = { (scaleIn(initialScale = 0.94f) + fadeIn()) togetherWith fadeOut() },
                label = "card",
            ) { i ->
                val (fact, artwork) = deck[i]
                val dx = if (i == index) drag.value.x else 0f
                FactCard(
                    fact, artwork, answer = if (i == index) answer else null,
                    trueStamp = if (answer == null) (dx / threshold).coerceIn(0f, 1f) else 0f,
                    falseStamp = if (answer == null) (-dx / threshold).coerceIn(0f, 1f) else 0f,
                    modifier = Modifier
                        .graphicsLayer {
                            translationX = dx
                            translationY = drag.value.y * 0.2f
                            rotationZ = (dx / density) / 18f
                        }
                        .pointerInput(i) {
                            detectDragGestures(
                                onDragEnd = {
                                    if (answer != null) return@detectDragGestures
                                    val x = drag.value.x
                                    when {
                                        x > threshold -> respond(true)
                                        x < -threshold -> respond(false)
                                        else -> scope.launch { drag.animateTo(Offset.Zero, Anim.bouncy()) }
                                    }
                                },
                            ) { change, amount ->
                                if (answer != null) return@detectDragGestures
                                change.consume()
                                scope.launch { drag.snapTo(drag.value + amount) }
                                // Haptic tick when the card crosses the answer threshold.
                                val nowArmed = abs(drag.value.x + amount.x) > threshold
                                if (nowArmed != armed) { armed = nowArmed; Haptics.selection() }
                            }
                        },
                )
            }
        }

        Spacer(Modifier.weight(0.001f))

        AnimatedContent(answer == null, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "buttons") { open ->
            if (open) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    PillButton(L("False"), Modifier.weight(1f), fill = Palette.redSoft, lip = hexColor(0xF2C9C5), foreground = hexColor(0x8C1D18)) { respond(false) }
                    PillButton(L("True"), Modifier.weight(1f), fill = Palette.greenSoft, lip = hexColor(0xBFE6CD), foreground = hexColor(0x00663B)) { respond(true) }
                }
            } else {
                PillButton(if (index >= deck.size - 1) L("See my score") else L("Next")) { advance() }
            }
        }
    }
}

@Composable
private fun FactCard(fact: Fact, artwork: Artwork, answer: Boolean?, trueStamp: Float, falseStamp: Float, modifier: Modifier) {
    val isCorrect = answer != null && answer == fact.isTrue
    Column(
        modifier.fillMaxWidth().shadow(14.dp, RoundedCornerShape(24.dp), ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.12f))
            .clip(RoundedCornerShape(24.dp)).background(Palette.card),
    ) {
        Box(Modifier.fillMaxWidth().height(200.dp)) {
            ArtImage(artwork.image, Modifier.matchParentSize())
            Stamp(L("True"), Palette.green, Modifier.align(Alignment.TopStart).padding(14.dp).graphicsLayer { alpha = trueStamp })
            Stamp(L("False"), Palette.red, Modifier.align(Alignment.TopEnd).padding(14.dp).graphicsLayer { alpha = falseStamp })
        }
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(artwork.title, style = figtree(13, FontWeight.SemiBold), color = Palette.blueText)
            Text(fact.text, style = figtree(20, FontWeight.SemiBold), color = Palette.ink)
            AnimatedContent(answer != null, transitionSpec = { (fadeIn() + slideInVertically { 30 }) togetherWith fadeOut() }, label = "verdict") { answered ->
                if (answered) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(if (isCorrect) Palette.greenSoft else Palette.redSoft).padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(
                            if (isCorrect) L("Good eye!") else if (fact.isTrue) L("Not quite. It was true.") else L("Not quite. It was false."),
                            style = AType.bodyStrong, color = if (isCorrect) hexColor(0x00663B) else hexColor(0x8C1D18),
                        )
                        Text(fact.explanation, style = AType.small, color = Palette.ink)
                    }
                } else {
                    Text(L("Swipe right for true, left for false."), style = AType.caption, color = Palette.muted)
                }
            }
        }
    }
}

@Composable
private fun Stamp(text: String, color: Color, modifier: Modifier) {
    Text(
        text, style = figtree(20, FontWeight.Bold), color = Color.White,
        modifier = modifier.clip(RoundedCornerShape(12.dp)).background(color).padding(horizontal = 16.dp, vertical = 8.dp),
    )
}
