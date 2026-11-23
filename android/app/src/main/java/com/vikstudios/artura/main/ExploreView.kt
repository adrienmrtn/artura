package com.vikstudios.artura.main

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.ProgressTrack
import com.vikstudios.artura.core.SkyHeader
import com.vikstudios.artura.core.TagPill
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.ContentStore
import com.vikstudios.artura.data.Movement
import com.vikstudios.artura.data.UserStore
import java.text.Normalizer

private enum class ExploreFilter {
    Movements, Artists, Periods, Museums;

    val label: String
        get() = when (this) {
            Movements -> L("Movements")
            Artists -> L("Artists")
            Periods -> L("Periods")
            Museums -> L("Museums")
        }
}

/** Lowercase text without accents, for searching ("Ménines" matches "menines"). */
private fun folded(text: String): String =
    Normalizer.normalize(text, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExploreView() {
    val user = LocalUser.current
    val content = LocalContent.current
    var filter by rememberSaveable { mutableStateOf(ExploreFilter.Movements) }
    var query by rememberSaveable { mutableStateOf("") }
    var course by remember { mutableStateOf<Artwork?>(null) }
    var movement by remember { mutableStateOf<Movement?>(null) }
    val focus = LocalFocusManager.current
    val searching = query.isNotBlank()
    val results = remember(query, content.artworks) {
        val q = folded(query.trim())
        if (q.isEmpty()) emptyList() else content.artworks.filter { art ->
            folded("${art.title} ${art.artist} ${content.movement(art.movementId)?.name ?: ""}").contains(q)
        }
    }
    val done = { art: Artwork -> user.profile.completedLessons.contains(art.id) }

    // Scrolling hides the keyboard (`.scrollDismissesKeyboard(.immediately)`).
    val dismissKeyboard = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source == NestedScrollSource.UserInput && available.y != 0f) focus.clearFocus()
                return Offset.Zero
            }
        }
    }

    LazyColumn(Modifier.fillMaxSize().background(Palette.bg).nestedScroll(dismissKeyboard)) {
        item {
            SkyHeader {
                Column(Modifier.padding(horizontal = 24.dp).padding(top = 60.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(L("Explore"), style = figtree(28, FontWeight.SemiBold), color = Color.White)
                    Row(
                        Modifier.fillMaxWidth().height(48.dp).clip(CircleShape).background(Color.White).padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(Icons.Rounded.Search, null, tint = Palette.ink, modifier = Modifier.size(20.dp))
                        Box(Modifier.weight(1f)) {
                            if (query.isEmpty()) Text(L("Artwork, artist, movement…"), style = figtree(15), color = Palette.muted)
                            BasicTextField(
                                query, { query = it },
                                singleLine = true,
                                textStyle = figtree(15).copy(color = Palette.ink),
                                cursorBrush = SolidColor(Palette.blue),
                                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, imeAction = ImeAction.Search),
                                keyboardActions = KeyboardActions(onSearch = { focus.clearFocus() }),
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        if (query.isNotEmpty()) {
                            Icon(
                                Icons.Rounded.Cancel, L("Clear search"), tint = Palette.muted,
                                modifier = Modifier.size(20.dp).pressable { Haptics.tap(); query = "" },
                            )
                        }
                    }
                }
            }
        }

        val pad = Modifier.padding(horizontal = 24.dp).offset(y = (-16).dp)
        if (searching) {
            if (results.isEmpty()) {
                item { Text(L("No artwork matches “%@”.", query), style = AType.body, color = Palette.muted, modifier = pad.padding(top = 24.dp)) }
            } else {
                items(results, key = { "r" + it.id }) { art ->
                    ArtworkRow(art, done(art), pad.padding(bottom = 14.dp)) { course = art }
                }
            }
        } else {
            item { Filters(filter, pad.padding(bottom = 14.dp)) { filter = it } }
            when (filter) {
                ExploreFilter.Movements -> movementsList(content, user, pad, onMovement = { movement = it })
                ExploreFilter.Artists -> grouped(content.artworks, { it.artist }, pad, done) { course = it }
                ExploreFilter.Periods -> items(content.artworks.sortedBy { it.year }, key = { "p" + it.id }) { art ->
                    Row(pad.padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(art.yearLabel, style = figtree(15, FontWeight.SemiBold), color = Palette.blueText, modifier = Modifier.width(48.dp), maxLines = 2)
                        ArtworkRow(art, done(art), Modifier.weight(1f)) { course = art }
                    }
                }
                ExploreFilter.Museums -> grouped(content.artworks, { it.museum }, pad, done) { course = it }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }

    val shownCourse = course
    FullScreenCover(visible = shownCourse != null, onDismiss = { course = null }) {
        if (shownCourse != null) CourseFlow(shownCourse) { course = null }
    }

    val shownMovement = movement
    if (shownMovement != null) {
        ModalBottomSheet(
            onDismissRequest = { movement = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Palette.bg,
        ) {
            MovementDetailView(shownMovement) { art ->
                // Covers are drawn under a sheet: the sheet closes, then the lesson opens.
                movement = null
                course = art
            }
        }
    }
}

@Composable
private fun Filters(selected: ExploreFilter, modifier: Modifier, onSelect: (ExploreFilter) -> Unit) {
    Row(modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ExploreFilter.entries.forEach { item ->
            val on = selected == item
            Box(
                Modifier.height(40.dp).pressable { Haptics.selection(); onSelect(item) }
                    .clip(CircleShape).background(if (on) Palette.ink else Palette.card).padding(horizontal = 16.dp),
                contentAlignment = Alignment.Center,
            ) { Text(item.label, style = figtree(14, FontWeight.SemiBold), color = if (on) Color.White else Palette.ink) }
        }
    }
}

private fun LazyListScope.movementsList(content: ContentStore, user: UserStore, pad: Modifier, onMovement: (Movement) -> Unit) {
    val current = content.movement(content.artwork(user.profile.firstCourse)?.movementId) ?: content.movements.firstOrNull()
    val cover = current?.let { content.artwork(it.cover) }
    if (current != null && cover != null) {
        item(key = "current") {
            val all = content.artworks(current.id)
            val done = all.count { user.profile.completedLessons.contains(it.id) }
            Row(
                pad.padding(bottom = 14.dp).appearUp(0.05).fillMaxWidth().height(124.dp).pressable { onMovement(current) }
                    .clip(RoundedCornerShape(16.dp)).background(Palette.yellow),
            ) {
                ArtImage(cover.image, Modifier.width(112.dp).fillMaxHeight())
                Column(Modifier.weight(1f).fillMaxHeight().padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(L("You're here · %@ of %@", "$done", "${all.size}"), style = figtree(12, FontWeight.SemiBold), color = Palette.ink)
                    Text(current.name, style = AType.cardTitle, color = Palette.ink, maxLines = 1)
                    Text(current.summary, style = AType.caption, color = Palette.ink, maxLines = 2)
                    Spacer(Modifier.weight(1f))
                    ProgressTrack(if (all.isEmpty()) 0.0 else done.toDouble() / all.size)
                }
            }
        }
    }
    item(key = "major") {
        Text(L("The major movements"), style = AType.heading, color = Palette.ink, modifier = pad.padding(top = 4.dp, bottom = 14.dp))
    }
    content.movements.forEachIndexed { i, m ->
        item(key = "m" + m.id) {
            Row(
                pad.padding(bottom = 14.dp).appearUp(0.05 * (i + 1)).fillMaxWidth().pressable { onMovement(m) },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                ArtImage(content.artwork(m.cover)?.image ?: "art_nuit", Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)), small = true)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(m.name, style = AType.bodyStrong, color = Palette.ink)
                    Text("${m.period} · ${m.summary}", style = AType.caption, color = Palette.muted)
                }
                Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.ink, modifier = Modifier.size(22.dp))
            }
        }
    }
}

private fun LazyListScope.grouped(
    artworks: List<Artwork>,
    key: (Artwork) -> String,
    pad: Modifier,
    done: (Artwork) -> Boolean,
    onOpen: (Artwork) -> Unit,
) {
    val groups = artworks.groupBy(key).toSortedMap()
    groups.forEach { (name, list) ->
        item(key = "g$name") {
            Text(name, style = AType.heading, color = Palette.ink, modifier = pad.padding(top = 6.dp, bottom = 10.dp))
        }
        items(list, key = { "g$name/" + it.id }) { art ->
            ArtworkRow(art, done(art), pad.padding(bottom = 10.dp)) { onOpen(art) }
        }
    }
}

/** Movement detail: an explanation, then the artworks to study. */
@Composable
fun MovementDetailView(movement: Movement, onOpen: (Artwork) -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        content.artwork(movement.cover)?.let { cover ->
            ArtImage(cover.image, Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(20.dp)))
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            TagPill(movement.period)
            Text(movement.name, style = AType.title, color = Palette.ink)
            // lineSpacing(5) on top of the font's line height
            Text(movement.description, style = figtree(17).copy(lineHeight = 26.sp), color = Palette.ink)
        }
        Text(L("The artworks"), style = AType.heading, color = Palette.ink)
        content.artworks(movement.id).forEach { art ->
            ArtworkRow(art, user.profile.completedLessons.contains(art.id)) { onOpen(art) }
        }
    }
}
