package com.vikstudios.artura.games

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
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
import com.vikstudios.artura.data.Fact

/**
 * Practice: today's questions (30 in total), mixing the four game types.
 * Each answer is counted right away, so you can leave and resume later.
 */
private data class Choice(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val colors: List<Color> = emptyList(),
    val thumb: String? = null,
)

private data class Round(
    val kind: String,
    val prompt: String,
    val image: String? = null,
    val zoom: Float = 1f,
    val anchor: Offset = Offset(0.5f, 0.5f),
    val statement: String? = null,
    val choices: List<Choice>,
    val correct: String,
    val explanation: String,
)

@Composable
fun TrainingGame(onFinish: (Int, Int) -> Unit) {
    val content = LocalContent.current
    val user = LocalUser.current
    /** Questions already answered today before this session. */
    val offset = remember { user.trainingDoneToday }
    val rounds = remember { buildRounds(content.artworks, content.allFacts, user.trainingRemaining) }
    var index by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<String?>(null) }
    var score by remember { mutableIntStateOf(0) }
    val round = rounds.getOrNull(index)
    val isLast = index >= rounds.size - 1

    fun pick(choice: Choice, round: Round) {
        if (picked != null) return
        picked = choice.id
        user.recordTrainingAnswer()
        if (choice.id == round.correct) { score++; Haptics.success() } else Haptics.error()
    }

    fun advance() {
        Haptics.tap()
        if (isLast) onFinish(score, rounds.size) else { picked = null; index++ }
    }

    key(index) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (round == null) return@Column
            // Game type, then question number out of the day's total, e.g. "Palette · 3 of 30"
            RoundHeader(L("%@ · %@ of %@", round.kind, "${offset + index + 1}", "${offset + rounds.size}"), score)
            Text(round.prompt, style = AType.titleSmall, color = Palette.ink)

            if (round.image != null) {
                val zoom by animateFloatAsState(if (picked == null) round.zoom else 1f, tween(300), label = "zoom")
                ArtImage(round.image, Modifier.fillMaxWidth().height(if (round.statement == null) 230.dp else 170.dp).clip(RoundedCornerShape(20.dp)),
                    zoom = zoom, anchor = round.anchor)
            }
            if (round.statement != null) {
                Text(round.statement, style = figtree(20, FontWeight.SemiBold), color = Palette.ink)
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                round.choices.forEach { choice ->
                    val answered = picked != null
                    val isAnswer = choice.id == round.correct
                    val (fill, border) = answerColors(answered, isAnswer, choice.id == picked)
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp)
                            .semantics { contentDescription = if (choice.colors.isEmpty()) choice.title else L("Palette") }
                            .pressable(enabled = !answered) { pick(choice, round) }
                            .answerCard(fill, border)
                            .padding(horizontal = if (choice.thumb == null) 16.dp else 8.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        if (choice.thumb != null) ArtImage(choice.thumb, Modifier.size(56.dp).clip(RoundedCornerShape(10.dp)), small = true)
                        if (choice.colors.isEmpty()) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                                Text(choice.title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink)
                                if (choice.subtitle != null) Text(choice.subtitle, style = figtree(12), color = Palette.muted)
                            }
                            Spacer(Modifier.width(0.dp))
                        } else {
                            SwatchRow(choice.colors, 36, Modifier.weight(1f))
                        }
                        if (answered && isAnswer) CheckBadge(Palette.green, 24.dp)
                    }
                }
            }

            AnimatedVisibility(picked != null, enter = fadeIn(tween(150))) {
                Text(
                    round.explanation, style = AType.small, color = Palette.ink,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                        .background(if (picked == round.correct) Palette.greenSoft else Palette.redSoft).padding(12.dp),
                )
            }

            Spacer(Modifier.weight(1f))

            AnimatedVisibility(picked != null, enter = fadeIn(tween(150))) {
                PillButton(if (isLast) L("Finish practice") else L("Next")) { advance() }
            }
        }
    }
}

// MARK: Building the questions

private fun buildRounds(arts: List<Artwork>, allFacts: List<Pair<Fact, Artwork>>, count: Int): List<Round> {
    if (arts.size < 4 || count <= 0) return emptyList()
    val base = listOf("zoom", "palette", "fact", "older")
    var facts = allFacts.shuffled().toMutableList()
    val result = mutableListOf<Round>()
    var previous: String? = null

    // Pick a random type for each question until we have enough.
    var attempts = 0
    while (result.size < count && attempts < count * 6) {
        attempts++
        val kind = base.random()
        // Never the same artwork twice in a row.
        val art = arts.filter { it.id != previous }.randomOrNull() ?: continue
        previous = art.id
        val others = arts.filter { it.id != art.id }.shuffled()
        when (kind) {
            "zoom" -> {
                val options = (others.take(3) + art).shuffled()
                result += Round(
                    kind = L("Mystery Zoom"), prompt = L("Which artwork is this detail from?"),
                    image = art.image, zoom = 4f, anchor = art.focusPoint,
                    choices = options.map { Choice(it.id, it.title, subtitle = it.artist) },
                    correct = art.id, explanation = "${art.title}, ${art.artist}.",
                )
            }
            "palette" -> {
                val options = (others.take(2) + art).shuffled()
                result += Round(
                    kind = L("Palette"), prompt = L("Which palette matches this painting?"),
                    image = art.image,
                    choices = options.map { Choice(it.id, it.title, colors = it.paletteColors) },
                    correct = art.id, explanation = L("These are the dominant colors of “%@”.", art.title),
                )
            }
            "fact" -> {
                if (facts.isEmpty()) facts = allFacts.shuffled().toMutableList()
                val (fact, artwork) = facts.removeLastOrNull() ?: continue
                result += Round(
                    kind = L("True or False"), prompt = L("True or false?"),
                    image = artwork.image, statement = fact.text,
                    choices = listOf(Choice("vrai", L("True")), Choice("faux", L("False"))),
                    correct = if (fact.isTrue) "vrai" else "faux", explanation = fact.explanation,
                )
            }
            else -> {
                val other = others.firstOrNull { it.year != art.year } ?: continue
                val pair = listOf(art, other).shuffled()
                val older = if (art.year < other.year) art else other
                result += Round(
                    kind = L("Timeline"), prompt = L("Which one is older?"),
                    choices = pair.map { Choice(it.id, it.title, subtitle = it.artist, thumb = it.image) },
                    correct = older.id,
                    explanation = "${pair[0].title}: ${pair[0].yearLabel}. ${pair[1].title}: ${pair[1].yearLabel}.",
                )
            }
        }
    }
    return result
}
