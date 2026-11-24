package com.vikstudios.artura.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.Anim
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

// Port of OnboardingQuestions.swift.

// MARK: Your first name

@Composable
fun NameScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    var name by remember { mutableStateOf(user.profile.firstName ?: "") }
    var focused by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val trimmed = name.trim()

    fun save() {
        user.update { it.copy(firstName = trimmed) }
        focusManager.clearFocus()
        onNext()
    }

    // The keyboard comes up once the screen has settled.
    LaunchedEffect(Unit) {
        delay(600)
        runCatching { focus.requestFocus() }
    }

    OnbScaffold(title = L("And you, what's your name?"), spoken = true, ctaEnabled = trimmed.isNotEmpty(), onNext = { save() }) {
        val border by animateColorAsState(if (focused) Palette.blue else Color.Transparent, Anim.snappy(), label = "border")
        val shape = RoundedCornerShape(18.dp)
        val style = figtree(24, FontWeight.SemiBold).copy(color = Palette.ink)
        Box(
            Modifier.fillMaxWidth().height(68.dp).enter(2.0)
                .clip(shape).background(Palette.card).border(2.dp, border, shape)
                .padding(horizontal = 18.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            if (name.isEmpty()) Text(L("Your first name"), style = style, color = Palette.muted.copy(alpha = 0.6f))
            BasicTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                textStyle = style,
                cursorBrush = SolidColor(Palette.blue),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { if (trimmed.isNotEmpty()) save() }),
                modifier = Modifier.fillMaxWidth().focusRequester(focus).onFocusChanged { focused = it.isFocused },
            )
        }
    }
}

// MARK: You are…

@Composable
fun GenderScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val name = user.profile.firstName
    val title = if (!name.isNullOrEmpty()) L("Nice to meet you, %@! You are…", name) else L("You are…")
    fun choose(value: String) = user.update { it.copy(gender = value) }

    OnbScaffold(
        title = title, subtitle = L("So I can address you the right way."), spoken = true,
        ctaEnabled = user.profile.gender != null, onNext = onNext,
    ) {
        Row(Modifier.fillMaxWidth().enter(2.0), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Portrait("ill_av1", L("A woman"), user.profile.gender == "femme", Modifier.weight(1f)) { choose("femme") }
            Portrait("ill_av2", L("A man"), user.profile.gender == "homme", Modifier.weight(1f)) { choose("homme") }
        }
        Column(Modifier.enter(3.5), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ChoiceRow(title = L("Other"), selected = user.profile.gender == "autre") { choose("autre") }
            ChoiceRow(title = L("I'd rather not say"), selected = user.profile.gender == "na") { choose("na") }
        }
    }
}

@Composable
private fun Portrait(image: String, label: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Box(modifier.pressable { Haptics.selection(); onClick() }) {
        Column(
            Modifier.fillMaxWidth().clip(shape).background(if (selected) Palette.mistLight else Palette.card)
                .border(3.dp, if (selected) Palette.blue else Color.Transparent, shape).padding(bottom = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ArtImage(image, Modifier.fillMaxWidth().height(132.dp))
            Text(label, style = figtree(17, FontWeight.SemiBold), color = Palette.ink)
        }
        AnimatedVisibility(selected, Modifier.align(Alignment.TopEnd).padding(8.dp), enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
            CheckBadge()
        }
    }
}

// MARK: What brings you here? (multiple answers)

@Composable
fun MotivationScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    // First: the stored value (English); second: what is shown.
    val options = listOf(
        Triple("Learn about art", L("Learn about art"), "ill_goal_art"),
        Triple("Become more cultured", L("Become more cultured"), "ill_goal_culture"),
        Triple("Have new things to talk about", L("Have new things to talk about"), "ill_goal_talk"),
        Triple("Prepare for an exam", L("Prepare for an exam"), "ill_goal_exam"),
        Triple("Just for fun", L("Just for fun"), "ill_goal_fun"),
    )
    val chosen = user.profile.goals ?: emptyList()

    fun toggle(title: String) {
        val goals = if (chosen.contains(title)) chosen - title else chosen + title
        // The first motivation remains the "goal" recalled in the program.
        user.update { it.copy(goals = goals, goal = goals.firstOrNull()) }
    }

    OnbScaffold(
        title = L("What brings you here?"), subtitle = L("Choose as many as you like."), spoken = true,
        ctaEnabled = chosen.isNotEmpty(), onNext = onNext,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEachIndexed { i, (value, label, image) ->
                Box(Modifier.enter(i + 2.0)) {
                    ChoiceRow(title = label, image = image, selected = chosen.contains(value), multiple = true) { toggle(value) }
                }
            }
        }
    }
}

// MARK: Your arts

private data class ArtForm(val id: String, val title: String, val image: String, val soon: Boolean)

@Composable
fun ArtsScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    val arts = listOf(
        ArtForm("peinture", L("Painting"), "ill_palette", false),
        ArtForm("sculpture", L("Sculpture"), "ill_sculpture", true),
        ArtForm("architecture", L("Architecture"), "ill_musee", true),
        ArtForm("photographie", L("Photography"), "ill_photo", true),
    )
    OnbScaffold(
        title = L("Any art forms you'd like to explore?"), subtitle = L("Painting is ready. The others are on their way."),
        spoken = true, ctaEnabled = user.profile.arts.isNotEmpty(), onNext = onNext,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            arts.chunked(2).forEachIndexed { row, pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    pair.forEachIndexed { col, art ->
                        val i = row * 2 + col
                        val selected = user.profile.arts.contains(art.id)
                        val shape = RoundedCornerShape(18.dp)
                        Box(
                            Modifier.weight(1f).enter(i * 0.7 + 2).pressable {
                                Haptics.selection()
                                user.update { p -> p.copy(arts = if (p.arts.contains(art.id)) p.arts - art.id else p.arts + art.id) }
                            }
                        ) {
                            Column(
                                Modifier.fillMaxWidth().clip(shape).background(if (selected) Palette.mistLight else Palette.card)
                                    .border(3.dp, if (selected) Palette.blue else Color.Transparent, shape),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Box {
                                    ArtImage(art.image, Modifier.fillMaxWidth().height(96.dp))
                                    if (art.soon) {
                                        Text(L("Soon"), style = figtree(11, FontWeight.SemiBold), color = Palette.ink,
                                            modifier = Modifier.padding(8.dp).clip(CircleShape).background(Palette.bg)
                                                .padding(horizontal = 8.dp, vertical = 3.dp))
                                    }
                                }
                                Text(art.title, style = AType.bodyStrong, color = Palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp))
                            }
                            androidx.compose.animation.AnimatedVisibility(selected, Modifier.align(Alignment.TopEnd).padding(8.dp), enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
                                CheckBadge(Palette.blue)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: Single-choice question (shared template)

data class ChoiceOption(
    /** Stored value (English). */
    val title: String,
    /** Text shown, when it differs from the stored value. */
    val label: String? = null,
    val subtitle: String? = null,
)

@Composable
fun ChoiceScreen(
    title: String,
    options: List<ChoiceOption>,
    selection: String?,
    onSelect: (String) -> Unit,
    onNext: () -> Unit,
    subtitle: String? = null,
) {
    OnbScaffold(title = title, subtitle = subtitle, spoken = true, ctaEnabled = selection != null, onNext = onNext) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            options.forEachIndexed { i, option ->
                Box(Modifier.enter(i + 2.0)) {
                    ChoiceRow(title = option.label ?: option.title, subtitle = option.subtitle, selected = selection == option.title) {
                        onSelect(option.title)
                    }
                }
            }
        }
    }
}

// MARK: Artworks you can't name

@Composable
fun RecognizeScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    ChoiceScreen(
        title = L("Do you often see artworks you can't name?"),
        subtitle = L("In a movie, on a poster, at a friend's place."),
        options = listOf(
            ChoiceOption("All the time", L("All the time")),
            ChoiceOption("Sometimes", L("Sometimes")),
            ChoiceOption("Rarely", L("Rarely")),
        ),
        selection = user.profile.unknownArt,
        onSelect = { v -> user.update { it.copy(unknownArt = v) } },
        onNext = onNext,
    )
}

// MARK: Your knowledge

@Composable
fun KnowledgeScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    // The option title is also the stored level (shown later on the profile).
    ChoiceScreen(
        title = L("How well do you know art history?"),
        subtitle = L("So I know where to start."),
        options = listOf(
            ChoiceOption("Beginner", L("Beginner"), L("Starting from scratch, and that's perfectly fine.")),
            ChoiceOption("Enthusiast", L("Enthusiast"), L("I know a few artists and movements.")),
            ChoiceOption("Connoisseur", L("Connoisseur"), L("I can tell a Monet from a Manet.")),
        ),
        selection = user.profile.level,
        onSelect = { v -> user.update { it.copy(level = v) } },
        onNext = onNext,
    )
}

// MARK: The museum

@Composable
fun MuseumScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    ChoiceScreen(
        title = L("Do you go to museums often?"),
        options = listOf(
            ChoiceOption("Almost never", L("Almost never")),
            ChoiceOption("Once or twice a year", L("Once or twice a year")),
            ChoiceOption("A few times a year", L("A few times a year")),
            ChoiceOption("Every chance I get", L("Every chance I get")),
        ),
        selection = user.profile.museumHabit,
        onSelect = { v -> user.update { it.copy(museumHabit = v) } },
        onNext = onNext,
    )
}

// MARK: Time spent on your phone

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun PhoneTimeScreen(onNext: () -> Unit) {
    val user = LocalUser.current
    /** Slider position, continuous. The kept value is rounded to the half hour. */
    var raw by remember { mutableFloatStateOf(user.profile.phoneHours.toFloat()) }
    val hours = (raw * 2).roundToInt() / 2.0
    val glow by rememberInfiniteTransition(label = "glow").animateFloat(
        1f, 1.08f, infiniteRepeatable(tween(5000), RepeatMode.Reverse), label = "zoom")

    // One tick per half hour crossed, not on every finger move.
    var lastHours by remember { mutableStateOf(hours) }
    LaunchedEffect(hours) {
        if (hours != lastHours) { Haptics.selection(); lastHours = hours }
    }

    OnbScaffold(
        title = L("How much time do you spend on your phone each day?"), spoken = true,
        onNext = {
            user.update { it.copy(phoneHours = hours) }
            onNext()
        },
    ) {
        ArtImage("ill_phone", Modifier.fillMaxWidth().height(170.dp).enter(2.0).clip(RoundedCornerShape(24.dp)),
            zoom = glow, anchor = Offset(0.5f, 0.45f))
        Column(Modifier.fillMaxWidth().enter(3.0), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(formatHours(hours), style = figtree(52, FontWeight.Bold).copy(fontFeatureSettings = "tnum"), color = Palette.ink)
            Text(L("per day"), style = AType.body, color = Palette.muted)
        }
        Column(Modifier.enter(4.0), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            // iOS-style slider: thin track, round white thumb.
            Slider(
                value = raw, onValueChange = { raw = it }, valueRange = 1f..10f,
                thumb = {
                    Box(Modifier.size(28.dp).shadow(4.dp, CircleShape).background(Color.White, CircleShape))
                },
                track = { state ->
                    val fraction = (state.value - state.valueRange.start) / (state.valueRange.endInclusive - state.valueRange.start)
                    Box(Modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(Palette.line)) {
                        Box(Modifier.fillMaxWidth(fraction).height(4.dp).background(Palette.blue))
                    }
                },
            )
            Row(Modifier.fillMaxWidth()) {
                Text(formatHours(1.0), style = AType.caption, color = Palette.muted)
                Spacer(Modifier.weight(1f))
                Text(formatHours(5.0), style = AType.caption, color = Palette.muted, textAlign = TextAlign.Center)
                Spacer(Modifier.weight(1f))
                Text(formatHours(10.0), style = AType.caption, color = Palette.muted)
            }
        }
    }
}

/** "4h" or "4h 30". */
fun formatHours(hours: Double): String {
    val whole = hours.toInt()
    return if (hours == whole.toDouble()) L("%@h", "$whole") else L("%@h 30", "$whole")
}
