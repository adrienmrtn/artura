package com.vikstudios.artura.review

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.rememberLastNonNull
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.SkyHeader
import com.vikstudios.artura.core.appearUp
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.feed.LibraryTab
import com.vikstudios.artura.feed.LibraryTile
import com.vikstudios.artura.feed.SegmentedPicker
import com.vikstudios.artura.main.CourseFlow

/**
 * Review tab: a daily set of cards drawn from what the user has read, and free practice on favorites,
 * on everything read, or on every artwork.
 */
@Composable
fun ReviewView() {
    val user = LocalUser.current
    val content = LocalContent.current
    /** Labels of the two modes, shown by the picker: [Review, Practice]. */
    val modes = listOf(L("Review"), L("Practice"))

    var practice by rememberSaveable { mutableStateOf(AppDebug.string("reviewMode") == "practice") }
    var deck by remember { mutableStateOf<ReviewDeck?>(null) }
    var course by remember { mutableStateOf<Artwork?>(null) }
    var library by remember { mutableStateOf<LibraryTab?>(null) }
    var opened by rememberSaveable { mutableStateOf(false) }

    val profile = user.profile
    /** Lessons finished, plus artworks opened: what the daily review draws from. */
    val readArtworks = (profile.completedLessons + profile.opened).distinct().mapNotNull { content.artwork(it) }
    val favoriteArtworks = profile.favorites.reversed().mapNotNull { content.artwork(it) }
    val savedArtworks = (profile.saved ?: emptyList()).reversed().mapNotNull { content.artwork(it) }
    val dailyCount = minOf(ReviewDeck.DAILY_SIZE, ReviewDeck.available(readArtworks, content.artworks))

    LaunchedEffect(Unit) {
        // Debug: open a session right away, for screenshots.
        if (!opened && AppDebug.flag("reviewSession")) {
            opened = true
            deck = ReviewDeck.daily(readArtworks, content.artworks)
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.bg).verticalScroll(rememberScrollState())) {
        SkyHeader {
            Column(Modifier.padding(start = 24.dp, top = 64.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(L("Review"), style = figtree(28, FontWeight.SemiBold), color = Color.White)
                Text(L("Remember what you've seen"), style = figtree(15), color = Color.White)
            }
        }
        Column(
            Modifier.offset(y = (-16).dp).padding(horizontal = 24.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SegmentedPicker(modes, if (practice) modes[1] else modes[0], onSelect = { practice = it == modes[1] })
            if (!practice) {
                TodayCard(
                    dailyCount = dailyCount,
                    doneToday = user.reviewDoneToday,
                    onStart = {
                        Haptics.press()
                        if (dailyCount == 0) content.artworkOfTheDay?.let { course = it }
                        else deck = ReviewDeck.daily(readArtworks, content.artworks)
                    },
                )
                Shelf(L("Saved"), Icons.Rounded.Bookmark, Palette.blue, savedArtworks,
                    L("Tap the bookmark on an artwork to read it later."), profile.completedLessons,
                    onSeeAll = { library = LibraryTab.Saved }, onOpen = { course = it })
                Shelf(L("Favorites"), Icons.Rounded.Favorite, Palette.orange, favoriteArtworks,
                    L("Tap the heart on an artwork to find it here."), profile.completedLessons,
                    onSeeAll = { library = LibraryTab.Favorites }, onOpen = { course = it })
            } else {
                Text(L("Choose what to practice"), style = AType.heading, color = Palette.ink)
                val all = content.artworks
                PracticeRow(L("My favorites"), L("The artworks you liked"), favoriteArtworks.firstOrNull()?.image ?: "ill_palette",
                    favoriteArtworks, all, L("Like an artwork first")) { deck = it }
                PracticeRow(L("Everything I've read"), L("Every lesson you've opened"), readArtworks.firstOrNull()?.image ?: "ill_oeil",
                    readArtworks, all, L("Read a lesson first")) { deck = it }
                PracticeRow(L("All artworks"), L("The whole collection, mixed"), "ill_galerie",
                    all, all, L("No artwork available")) { deck = it }
            }
        }
    }

    val shownDeck = rememberLastNonNull(deck)
    FullScreenCover(visible = deck != null, onDismiss = { deck = null }) {
        if (shownDeck != null) ReviewSessionView(shownDeck) { deck = null }
    }
    val shownCourse = rememberLastNonNull(course)
    FullScreenCover(visible = course != null, onDismiss = { course = null }) {
        if (shownCourse != null) CourseFlow(shownCourse) { course = null }
    }
    library?.let { tab ->
        // Lessons and sessions open over the whole app: the sheet closes first (it is a window above the covers).
        ReviewLibrarySheet(tab, onDismiss = { library = null },
            onOpen = { library = null; course = it },
            onPractice = { library = null; deck = it })
    }
}

// MARK: Today's review

@Composable
private fun TodayCard(dailyCount: Int, doneToday: Boolean, onStart: () -> Unit) {
    Column(Modifier.fillMaxWidth().appearUp(0.05).clip(RoundedCornerShape(20.dp)).background(Palette.card)) {
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(L("TODAY"), style = figtree(12, FontWeight.Bold).copy(letterSpacing = 2.5.sp), color = Palette.muted)
                if (dailyCount == 0) {
                    Text(L("Nothing to review yet"), style = figtree(22, FontWeight.SemiBold), color = Palette.ink)
                    Text(L("Read your first lesson, and its questions will come back here."), style = AType.small, color = Palette.muted)
                } else {
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("$dailyCount", style = figtree(52, FontWeight.Bold).copy(lineHeight = 56.sp), color = Palette.ink,
                            modifier = Modifier.alignByBaseline())
                        // Shown after the number of review cards, in a larger font ("10 cards").
                        Text(if (dailyCount == 1) L("card") else L("cards"), style = figtree(22, FontWeight.SemiBold), color = Palette.ink,
                            modifier = Modifier.alignByBaseline())
                    }
                    Text(if (doneToday) L("Done for today. Come back tomorrow for a new set.") else L("drawn from what you've read"),
                        style = AType.small, color = Palette.muted)
                }
            }
            ArtImage("ill_regard", Modifier.size(96.dp).clip(RoundedCornerShape(18.dp)))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.line))
        Row(
            Modifier.fillMaxWidth().height(56.dp).pressable(haptic = false, onClick = onStart).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (doneToday && dailyCount > 0) CheckBadge(Palette.green, 22.dp)
            Text(
                if (dailyCount == 0) L("Open today's artwork") else if (doneToday) L("Review again") else L("Review now"),
                style = figtree(17, FontWeight.SemiBold), color = Palette.ink, modifier = Modifier.weight(1f),
            )
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.ink, modifier = Modifier.size(22.dp))
        }
    }
}

// MARK: Saved and favorites

@Composable
private fun Shelf(
    title: String, icon: ImageVector, tint: Color, items: List<Artwork>, empty: String, done: List<String>,
    onSeeAll: () -> Unit, onOpen: (Artwork) -> Unit,
) {
    Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Text(title, style = AType.heading, color = Palette.ink, modifier = Modifier.weight(1f))
            if (items.isNotEmpty()) {
                Box(Modifier.height(32.dp).pressable { Haptics.tap(); onSeeAll() }, contentAlignment = Alignment.Center) {
                    Text(L("See all %@", "${items.size}"), style = figtree(14, FontWeight.SemiBold), color = Palette.blueText)
                }
            }
        }
        if (items.isEmpty()) {
            Text(empty, style = AType.small, color = Palette.muted,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(16.dp))
        } else {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                items.forEach { art -> LibraryTile(art, done = done.contains(art.id), modifier = Modifier.width(132.dp)) { onOpen(art) } }
            }
        }
    }
}

// MARK: Practice

@Composable
private fun PracticeRow(
    title: String, detail: String, image: String, artworks: List<Artwork>, all: List<Artwork>, empty: String,
    onStart: (ReviewDeck) -> Unit,
) {
    val available = ReviewDeck.available(artworks, all)
    Row(
        Modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = if (available == 0) 0.5f else 1f }
            .pressable(enabled = available > 0) {
                Haptics.press()
                onStart(ReviewDeck.practice(title, artworks, all))
            }
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.card),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ArtImage(image, Modifier.size(88.dp), small = true)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = AType.cardTitle, color = Palette.ink)
            Text(
                if (available == 0) empty else if (artworks.size == 1) L("%@ · 1 artwork", detail) else L("%@ · %@ artworks", detail, "${artworks.size}"),
                style = AType.caption, color = Palette.muted,
            )
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.ink, modifier = Modifier.padding(end = 14.dp).size(22.dp))
    }
}

// MARK: Library sheet ("See all")

/**
 * The library opened from a shelf: same screen as `LibraryView` (feed/LibraryView.swift), shown in a sheet.
 * Kept here so the Review tab does not depend on the feed's port; it can be replaced by the feed's LibraryView.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReviewLibrarySheet(initial: LibraryTab, onDismiss: () -> Unit, onOpen: (Artwork) -> Unit, onPractice: (ReviewDeck) -> Unit) {
    val user = LocalUser.current
    val content = LocalContent.current
    var tab by remember { mutableStateOf(initial) }
    val profile = user.profile
    val ids = when (tab) {
        LibraryTab.Favorites -> profile.favorites.reversed()
        LibraryTab.Saved -> (profile.saved ?: emptyList()).reversed()
        LibraryTab.History -> profile.opened.reversed()
    }
    val items = ids.mapNotNull { content.artwork(it) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Palette.bg,
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(0.92f).padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(L("My library"), style = AType.title, color = Palette.ink, modifier = Modifier.padding(top = 8.dp))
            val labels = LibraryTab.entries.map { it.label }
            SegmentedPicker(labels, tab.label, onSelect = { label -> tab = LibraryTab.entries.firstOrNull { it.label == label } ?: LibraryTab.Favorites })
            if (items.isEmpty()) {
                EmptyLibrary(tab)
            } else {
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    items.chunked(2).forEach { pair ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            pair.forEach { art ->
                                LibraryTile(art, done = profile.completedLessons.contains(art.id), modifier = Modifier.weight(1f)) { onOpen(art) }
                            }
                            if (pair.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
                PillButton(
                    if (items.size == 1) L("Practice this artwork") else L("Practice these %@ artworks", "${items.size}"),
                    Modifier.padding(bottom = 16.dp),
                ) {
                    Haptics.press()
                    onPractice(ReviewDeck.practice(tab.label, items, content.artworks))
                }
            }
        }
    }
}

@Composable
private fun ColumnScope.EmptyLibrary(tab: LibraryTab) {
    val (title, detail) = when (tab) {
        LibraryTab.Favorites -> L("No favorites yet") to L("Tap the heart on an artwork to find it here.")
        LibraryTab.Saved -> L("Nothing saved yet") to L("Tap the bookmark on an artwork to read it later.")
        LibraryTab.History -> L("No history yet") to L("The artworks you open will show up here.")
    }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(vertical = 48.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(tab.emptyIcon, null, tint = Palette.muted, modifier = Modifier.size(32.dp))
        Text(title, style = AType.bodyStrong, color = Palette.ink)
        Text(detail, style = AType.small, color = Palette.muted, textAlign = TextAlign.Center)
    }
    Spacer(Modifier.weight(1f))
}
