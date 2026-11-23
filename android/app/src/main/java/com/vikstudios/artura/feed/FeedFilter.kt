package com.vikstudios.artura.feed

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.AppLanguage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.main.ArtworkRow
import com.vikstudios.artura.main.CourseFlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.Normalizer

// MARK: - Filter model

/** What the home feed is narrowed to. Everything is optional: an empty filter shows all artworks. */
data class FeedFilter(
    val movementId: String? = null,
    val artist: String? = null,
    /** Century of the artwork (15 = 15th century). */
    val century: Int? = null,
    val status: Status = Status.All,
) {
    enum class Status {
        All, Unread, Read;

        /** Label shown on screen. */
        val label: String
            get() = when (this) {
                All -> L("Everything")
                Unread -> L("Not read yet")
                Read -> L("Already read")
            }
    }

    val isActive: Boolean get() = movementId != null || artist != null || century != null || status != Status.All

    /** Number of criteria currently set, shown on the filter button. */
    val count: Int get() = listOf(movementId != null, artist != null, century != null, status != Status.All).count { it }

    fun matches(artwork: Artwork, read: Boolean): Boolean {
        if (movementId != null && artwork.movementId != movementId) return false
        if (artist != null && artwork.artist != artist) return false
        if (century != null && century(artwork.year) != century) return false
        return when (status) {
            Status.All -> true
            Status.Unread -> !read
            Status.Read -> read
        }
    }

    companion object {
        fun century(year: Int): Int = if (year > 0) (year - 1) / 100 + 1 else 0

        /** "19th century". */
        fun label(century: Int): String {
            // "%@" is the century number (Roman numerals in the languages of `romanCenturies`);
            // the English ordinal suffix (st, nd, rd, th) depends on it.
            val number = if (AppLanguage.code in romanCenturies) roman(century) else "$century"
            return when {
                century % 100 in 11..13 -> L("%@th century", number)
                century % 10 == 1 -> L("%@st century", number)
                century % 10 == 2 -> L("%@nd century", number)
                century % 10 == 3 -> L("%@rd century", number)
                else -> L("%@th century", number)
            }
        }

        /** Languages that write centuries in Roman numerals ("XIXe siècle", "siglo XIX", "XIX век"). */
        private val romanCenturies = setOf("fr", "es", "it", "pt-BR", "pt-PT", "ro", "pl", "ru", "bg", "sr-Latn", "lt")

        private fun roman(n: Int): String {
            if (n <= 0) return "$n"
            val table = listOf(10 to "X", 9 to "IX", 5 to "V", 4 to "IV", 1 to "I")
            var rest = n
            val out = StringBuilder()
            for ((value, letters) in table) while (rest >= value) { out.append(letters); rest -= value }
            return out.toString()
        }
    }
}

// MARK: - Sheets (iOS `.sheet` with the large detent and the drag indicator)

/**
 * A sheet sliding up over the app, with a grabber; swipe it down or use back to close it.
 * Built on `FullScreenCover`, so a lesson opened from inside the sheet shows above it, as on iOS.
 */
@Composable
fun FeedSheetCover(visible: Boolean, onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    FullScreenCover(visible = visible, onDismiss = onDismiss, transparent = true) {
        SheetPanel(onDismiss, content)
    }
}

@Composable
fun SheetPanel(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val drag = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f))
                .clickable(remember { MutableInteractionSource() }, null) { onDismiss() }
        )
        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Spacer(Modifier.height(10.dp))
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .graphicsLayer { translationY = drag.value }
                    .background(Palette.bg, RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp))
                    .clickable(remember { MutableInteractionSource() }, null) {}
                    .navigationBarsPadding()
                    .imePadding(),
            ) {
                // Grabber: drag it down to close the sheet.
                Box(
                    Modifier.fillMaxWidth().height(22.dp).pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onDragEnd = {
                                scope.launch {
                                    if (drag.value > 120.dp.toPx()) { Haptics.tap(); onDismiss() }
                                    drag.animateTo(0f, tween(200))
                                }
                            },
                            onVerticalDrag = { change, amount ->
                                change.consume()
                                scope.launch { drag.snapTo((drag.value + amount).coerceAtLeast(0f)) }
                            },
                        )
                    },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(Modifier.size(36.dp, 5.dp).background(Palette.lip, CircleShape))
                }
                content()
            }
        }
    }
}

// MARK: - Chips that wrap onto several lines

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChipFlow(spacing: Dp = 8.dp, content: @Composable () -> Unit) {
    FlowRow(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(spacing),
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) { content() }
}

/** Selectable chip used in the filter sheet and the search suggestions. */
@Composable
fun FilterChip(title: String, selected: Boolean, onClick: () -> Unit) {
    val fill by animateColorAsState(if (selected) Palette.blue else Color.White, tween(160), label = "chip")
    val ink by animateColorAsState(if (selected) Color.White else Palette.ink, tween(160), label = "chipText")
    Box(
        Modifier
            .height(40.dp)
            .pressable(haptic = false) { Haptics.selection(); onClick() }
            .background(fill, CircleShape)
            .border(1.dp, if (selected) Palette.blue else Palette.line, CircleShape)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = figtree(14, FontWeight.SemiBold), color = ink, maxLines = 1)
    }
}

// MARK: - Filter sheet

@Composable
fun FeedFilterSheet(filter: FeedFilter, onApply: (FeedFilter) -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    /** Edited copy: the feed only changes when the user confirms. */
    var draft by remember { mutableStateOf(filter) }

    val artists = content.artworks.map { it.artist }.toSet().sorted()
    val centuries = content.artworks.map { FeedFilter.century(it.year) }.toSet().sorted()
    val matchCount = content.artworks.count { draft.matches(it, user.profile.completedLessons.contains(it.id)) }

    Column(Modifier.fillMaxSize().background(Palette.bg)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 2.dp).height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(L("Filter your feed"), style = AType.titleSmall, color = Palette.ink, modifier = Modifier.weight(1f))
            if (draft.isActive) {
                Box(Modifier.height(44.dp).pressable { draft = FeedFilter() }, contentAlignment = Alignment.Center) {
                    Text(L("Reset"), style = figtree(15, FontWeight.SemiBold), color = Palette.blueText)
                }
            }
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            FilterSection(L("Movement")) {
                content.movements.forEach { m ->
                    FilterChip(m.name, draft.movementId == m.id) {
                        draft = draft.copy(movementId = if (draft.movementId == m.id) null else m.id)
                    }
                }
            }
            FilterSection(L("Period")) {
                centuries.forEach { c ->
                    FilterChip(FeedFilter.label(c), draft.century == c) {
                        draft = draft.copy(century = if (draft.century == c) null else c)
                    }
                }
            }
            FilterSection(L("Artist")) {
                artists.forEach { a ->
                    FilterChip(a, draft.artist == a) { draft = draft.copy(artist = if (draft.artist == a) null else a) }
                }
            }
            FilterSection(L("Show")) {
                FeedFilter.Status.entries.forEach { s -> FilterChip(s.label, draft.status == s) { draft = draft.copy(status = s) } }
            }
        }
        val title = when (matchCount) {
            0 -> L("No artwork matches")
            1 -> L("Show 1 artwork")
            else -> L("Show %@ artworks", "$matchCount")
        }
        PillButton(
            title,
            Modifier.padding(horizontal = 24.dp).padding(bottom = 16.dp).graphicsLayer { alpha = if (matchCount == 0) 0.4f else 1f },
            enabled = matchCount > 0,
        ) {
            onApply(draft)
        }
    }
}

@Composable
private fun FilterSection(title: String, chips: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, style = AType.heading, color = Palette.ink)
        ChipFlow(8.dp, chips)
    }
}

// MARK: - Search sheet

/** Text without accents, in lower case, for searching ("Mélancolie" → "melancolie"). */
private fun String.folded(): String =
    Normalizer.normalize(this, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase(AppLanguage.locale)

/**
 * Search sheet. `onFilter` lets a suggestion narrow the feed (for example, to one movement) and closes the sheet.
 */
@Composable
fun FeedSearchSheet(onFilter: (FeedFilter) -> Unit, autoFocus: Boolean = true) {
    val user = LocalUser.current
    val content = LocalContent.current
    var query by remember { mutableStateOf("") }
    var course by remember { mutableStateOf<Artwork?>(null) }
    var focused by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    val trimmed = query.trim()
    val results = run {
        val needle = trimmed.folded()
        if (needle.isEmpty()) emptyList() else content.artworks.filter { art ->
            "${art.title} ${art.artist} ${art.museum} ${content.movement(art.movementId)?.name ?: ""}".folded().contains(needle)
        }
    }
    val recent = user.profile.opened.reversed().take(4).mapNotNull { content.artwork(it) }

    LaunchedEffect(Unit) {
        if (!autoFocus) return@LaunchedEffect
        delay(400)
        runCatching { focus.requestFocus() }
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(
            Modifier
                .padding(top = 2.dp)
                .fillMaxWidth()
                .height(52.dp)
                .background(Color.White, CircleShape)
                .border(if (focused) 2.dp else 1.dp, if (focused) Palette.blue else Palette.line, CircleShape)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Rounded.Search, null, tint = Palette.ink, modifier = Modifier.size(22.dp))
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                if (query.isEmpty()) Text(L("Artwork, artist, movement…"), style = figtree(16), color = Palette.muted)
                BasicTextField(
                    query, { query = it },
                    textStyle = figtree(16).copy(color = Palette.ink),
                    singleLine = true,
                    cursorBrush = SolidColor(Palette.blue),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                    modifier = Modifier.fillMaxWidth().focusRequester(focus).onFocusChanged { focused = it.isFocused },
                )
            }
            if (query.isNotEmpty()) {
                Box(Modifier.size(28.dp).pressable { query = "" }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Cancel, L("Clear search"), tint = Palette.muted, modifier = Modifier.size(20.dp))
                }
            }
        }

        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            when {
                trimmed.isEmpty() -> {
                    Text(L("Browse by movement"), style = AType.heading, color = Palette.ink)
                    ChipFlow(8.dp) {
                        content.movements.forEach { m ->
                            FilterChip(m.name, false) { onFilter(FeedFilter(movementId = m.id)) }
                        }
                    }
                    if (recent.isNotEmpty()) {
                        Text(L("Recently opened"), style = AType.heading, color = Palette.ink, modifier = Modifier.padding(top = 8.dp))
                        recent.forEach { art ->
                            ArtworkRow(art, user.profile.completedLessons.contains(art.id)) { course = art }
                        }
                    }
                }
                results.isEmpty() -> Text(L("No artwork matches “%@”.", trimmed), style = AType.body, color = Palette.muted, modifier = Modifier.padding(top = 12.dp))
                else -> results.forEach { art ->
                    ArtworkRow(art, user.profile.completedLessons.contains(art.id)) { focusManager.clearFocus(); course = art }
                }
            }
        }
    }

    val open = course
    FullScreenCover(visible = open != null, onDismiss = { course = null }) {
        if (open != null) CourseFlow(open) { course = null }
    }
}
