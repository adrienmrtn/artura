package com.vikstudios.artura.feed

import com.vikstudios.artura.app.rememberLastNonNull
import com.vikstudios.artura.review.ReviewDeck
import com.vikstudios.artura.review.ReviewSessionView

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.History
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Icon
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.style.TextAlign
import com.vikstudios.artura.app.FullScreenCover
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.main.CourseFlow

// Port of LibraryView.swift. LibraryTab, LibraryTile and SegmentedPicker are also used by the Review tab.

enum class LibraryTab {
    Favorites, Saved, History;

    /** Name shown on screen. */
    val label: String
        get() = when (this) {
            Favorites -> L("Favorites")
            Saved -> L("Saved")
            History -> L("History")
        }

    val emptyIcon: ImageVector
        get() = when (this) {
            Favorites -> Icons.Rounded.FavoriteBorder
            Saved -> Icons.Rounded.BookmarkBorder
            History -> Icons.Rounded.History
        }

    val emptyTitle: String
        get() = when (this) {
            Favorites -> L("No favorites yet")
            Saved -> L("Nothing saved yet")
            History -> L("No history yet")
        }

    val emptyDetail: String
        get() = when (this) {
            Favorites -> L("Tap the heart on an artwork to find it here.")
            Saved -> L("Tap the bookmark on an artwork to read it later.")
            History -> L("The artworks you open will show up here.")
        }
}


/** The user's library: liked artworks, saved artworks and the ones already opened. Shown in a sheet. */
@Composable
fun LibraryView(initialTab: LibraryTab) {
    val user = LocalUser.current
    val content = LocalContent.current
    var tab by remember { mutableStateOf(initialTab) }
    var course by remember { mutableStateOf<Artwork?>(null) }
    var deck by remember { mutableStateOf<ReviewDeck?>(null) }

    val ids = when (tab) {
        LibraryTab.Favorites -> user.profile.favorites.reversed()
        LibraryTab.Saved -> (user.profile.saved ?: emptyList()).reversed()
        LibraryTab.History -> user.profile.opened.reversed()
    }
    val items = ids.mapNotNull { content.artwork(it) }

    Column(Modifier.fillMaxSize().background(Palette.bg).padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(L("My library"), style = AType.title, color = Palette.ink, modifier = Modifier.padding(top = 2.dp))
        SegmentedPicker(LibraryTab.entries.map { it.label }, tab.label, { label ->
            tab = LibraryTab.entries.firstOrNull { it.label == label } ?: LibraryTab.Favorites
        })
        if (items.isEmpty()) {
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.card).padding(vertical = 48.dp, horizontal = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(tab.emptyIcon, null, tint = Palette.muted, modifier = Modifier.size(34.dp))
                Text(tab.emptyTitle, style = AType.bodyStrong, color = Palette.ink)
                Text(tab.emptyDetail, style = AType.small, color = Palette.muted, textAlign = TextAlign.Center)
            }
        } else {
            LazyVerticalGrid(
                GridCells.Fixed(2),
                Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
                contentPadding = PaddingValues(bottom = 16.dp),
            ) {
                items(items, key = { it.id }) { art ->
                    LibraryTile(art, user.profile.completedLessons.contains(art.id)) { course = art }
                }
            }
            PillButton(
                if (items.size == 1) L("Practice this artwork") else L("Practice these %@ artworks", "${items.size}"),
                Modifier.padding(bottom = 16.dp),
            ) {
                Haptics.press()
                deck = ReviewDeck.practice(tab.label, items, content.artworks)
            }
        }
    }

    val open = rememberLastNonNull(course)
    FullScreenCover(visible = course != null, onDismiss = { course = null }) {
        if (open != null) CourseFlow(open) { course = null }
    }
    val shownDeck = rememberLastNonNull(deck)
    FullScreenCover(visible = deck != null, onDismiss = { deck = null }) {
        if (shownDeck != null) ReviewSessionView(shownDeck) { deck = null }
    }
}

/** Square thumbnail with the title underneath. */
@Composable
fun LibraryTile(artwork: Artwork, done: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(modifier.pressable(onClick = onClick), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(16.dp))) {
            ArtImage(artwork.image, Modifier.matchParentSize(), small = true)
            if (done) Box(Modifier.align(Alignment.TopEnd).padding(8.dp)) { CheckBadge(Palette.green, 24.dp) }
        }
        Text(artwork.title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(artwork.artist, style = AType.caption, color = Palette.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Capsule selector with a white pill under the active option (same look as the app's other selectors). */
@Composable
fun SegmentedPicker(options: List<String>, selection: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().clip(CircleShape).background(Palette.card).padding(4.dp)) {
        options.forEach { option ->
            val selected = selection == option
            val a by animateFloatAsState(if (selected) 1f else 0f, label = "seg")
            Box(
                Modifier.weight(1f).height(40.dp).clip(CircleShape).background((if (Palette.isDark) Palette.lip else Color.White).copy(alpha = a))
                    .pressable { if (!selected) { Haptics.selection(); onSelect(option) } },
                contentAlignment = Alignment.Center,
            ) {
                Text(option, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, maxLines = 1)
            }
        }
    }
}
