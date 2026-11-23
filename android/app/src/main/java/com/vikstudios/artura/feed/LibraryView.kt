package com.vikstudios.artura.feed

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

// Port of LibraryView.swift. LibraryTab, LibraryTile and SegmentedPicker are also used by the Review tab.
// The library sheet itself (LibraryView) is still to be ported below.

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
                Modifier.weight(1f).height(40.dp).clip(CircleShape).background(Color.White.copy(alpha = a))
                    .pressable { if (!selected) { Haptics.selection(); onSelect(option) } },
                contentAlignment = Alignment.Center,
            ) {
                Text(option, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, maxLines = 1)
            }
        }
    }
}
