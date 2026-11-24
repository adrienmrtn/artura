package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ZoomOut
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork

/** Mystery Zoom: a heavily magnified detail, four options. You can zoom out for help. */
@Composable
fun ZoomGame(onFinish: (Int, Int) -> Unit) {
    val content = LocalContent.current
    val zooms = listOf(6f, 3.5f, 2f)
    val rounds = remember { content.artworks.shuffled().take(5) }
    var index by remember { mutableIntStateOf(0) }
    var zoomStep by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf<String?>(null) }
    var score by remember { mutableIntStateOf(0) }

    fun optionsFor(i: Int): List<Artwork> {
        val current = rounds.getOrNull(i) ?: return emptyList()
        val others = content.artworks.filter { it.id != current.id }.shuffled().take(3)
        return (others + current).shuffled()
    }
    var options by remember { mutableStateOf(optionsFor(0)) }

    val current = rounds.getOrNull(index)
    val zoomTarget = if (selected != null) 1f else zooms[minOf(zoomStep, zooms.size - 1)]
    val zoom by animateFloatAsState(zoomTarget, spring(dampingRatio = 0.8f, stiffness = 80f), label = "zoom")

    fun pick(option: Artwork, correct: Artwork) {
        if (selected != null) return
        selected = option.id
        if (option.id == correct.id) { score++; Haptics.success() } else Haptics.error()
    }

    fun advance() {
        Haptics.tap()
        if (index >= rounds.size - 1) {
            onFinish(score, rounds.size)
        } else {
            index++
            options = optionsFor(index)
            zoomStep = 0
            selected = null
        }
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (current == null) return@Column
        RoundHeader(L("Round %@ of %@", "${index + 1}", "${rounds.size}"), score)
        Text(L("Which artwork is this detail from?"), style = AType.titleSmall, color = Palette.ink)

        Box(Modifier.fillMaxWidth().height(290.dp).clip(RoundedCornerShape(20.dp))) {
            ArtImage(current.image, Modifier.fillMaxSize(), zoom = zoom, anchor = current.focusPoint)
            androidx.compose.animation.AnimatedVisibility(
                selected == null && zoomStep < zooms.size - 1,
                enter = fadeIn(), exit = fadeOut(),
                modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp),
            ) {
                Row(
                    Modifier.height(44.dp).clip(CircleShape).background(Palette.bg)
                        .pressable(haptic = false) { Haptics.soft(); zoomStep++ }
                        .padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Rounded.ZoomOut, null, tint = Palette.ink, modifier = Modifier.size(18.dp))
                    Text(L("Zoom out"), style = figtree(14, FontWeight.SemiBold), color = Palette.ink)
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            options.forEach { option ->
                val answered = selected != null
                val isAnswer = option.id == current.id
                val (fill, border) = answerColors(answered, isAnswer, option.id == selected)
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 52.dp)
                        .pressable(enabled = !answered) { pick(option, current) }
                        .answerCard(fill, border)
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        Text(option.title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
                        Text(option.artist, style = figtree(12), color = Palette.muted)
                    }
                    Spacer(Modifier.width(8.dp))
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
