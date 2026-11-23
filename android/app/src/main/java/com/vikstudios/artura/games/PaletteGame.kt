package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork

/** A row of color swatches (palette of a painting). */
@Composable
fun SwatchRow(colors: List<Color>, height: Int, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        colors.forEach { color ->
            val shape = RoundedCornerShape(10.dp)
            Box(Modifier.weight(1f).height(height.dp).clip(shape).background(color).border(1.dp, Color.Black.copy(alpha = 0.08f), shape))
        }
    }
}

/** Palette: pick, out of three palettes, the one from the painting shown. */
@Composable
fun PaletteGame(onFinish: (Int, Int) -> Unit) {
    val content = LocalContent.current
    val rounds = remember { content.artworks.filter { it.palette.isNotEmpty() }.shuffled().take(5) }
    var index by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<String?>(null) }
    var score by remember { mutableIntStateOf(0) }

    fun optionsFor(i: Int): List<Artwork> {
        val current = rounds.getOrNull(i) ?: return emptyList()
        val others = content.artworks.filter { it.id != current.id && it.palette.isNotEmpty() }.shuffled().take(2)
        return (others + current).shuffled()
    }
    var options by remember { mutableStateOf(optionsFor(0)) }
    val current = rounds.getOrNull(index)

    fun pick(option: Artwork, correct: Artwork) {
        if (selected != null) return
        selected = option.id
        if (option.id == correct.id) { score++; Haptics.success() } else Haptics.error()
    }

    fun advance() {
        if (index >= rounds.size - 1) {
            onFinish(score, rounds.size)
        } else {
            Haptics.tap()
            index++
            options = optionsFor(index)
            selected = null
        }
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (current == null) return@Column
        RoundHeader(L("Round %@ of %@", "${index + 1}", "${rounds.size}"), score)
        Text(L("Which palette matches this painting?"), style = AType.titleSmall, color = Palette.ink)

        AnimatedContent(current, transitionSpec = { fadeIn(Anim.gentle()) togetherWith fadeOut(Anim.gentle()) }, label = "painting") { art ->
            ArtImage(art.image, Modifier.fillMaxWidth().height(240.dp).clip(RoundedCornerShape(20.dp)))
        }
        Text("${current.title} · ${current.artist}", style = AType.caption, color = Palette.muted)

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEach { option ->
                val answered = selected != null
                val isAnswer = option.id == current.id
                val border = answerColors(answered, isAnswer, option.id == selected).second
                Row(
                    Modifier.fillMaxWidth()
                        .semantics { contentDescription = if (answered && isAnswer) L("Correct palette") else L("Palette") }
                        .pressable(enabled = !answered) { pick(option, current) }
                        .answerCard(Palette.card, border, radius = 16.dp, borderWidth = 3.dp)
                        .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SwatchRow(option.paletteColors, 40, Modifier.weight(1f))
                    AnimatedVisibility(answered && isAnswer, enter = scaleIn()) { CheckBadge(Palette.green, 24.dp) }
                }
            }
        }

        Spacer(Modifier.weight(1f))

        AnimatedVisibility(selected != null, enter = buttonEnter) {
            PillButton(if (index >= rounds.size - 1) L("See my score") else L("Next")) { advance() }
        }
    }
}
