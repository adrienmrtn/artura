package com.vikstudios.artura.main

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.app.LocalUser
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.figtree
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.feed.LibraryTab
import com.vikstudios.artura.feed.LibraryTile
import com.vikstudios.artura.feed.SegmentedPicker

/**
 * "My library" sheet opened from the profile (iOS: `LibraryView(tab: .favorites)`).
 * Interim version built on LibraryTab / LibraryTile / SegmentedPicker; once the feed's `LibraryView`
 * is ported, this should simply call it.
 */
@Composable
fun LibrarySheet(onClose: () -> Unit, onOpen: (Artwork) -> Unit = {}) {
    val user = LocalUser.current
    val content = LocalContent.current
    var tab by remember { mutableStateOf(LibraryTab.Favorites) }
    val ids = when (tab) {
        LibraryTab.Favorites -> user.profile.favorites
        LibraryTab.Saved -> user.profile.saved ?: emptyList()
        LibraryTab.History -> user.profile.opened.reversed()
    }
    val items = ids.mapNotNull { content.artwork(it) }
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(L("My library"), style = figtree(24, FontWeight.SemiBold), color = Palette.ink)
        SegmentedPicker(LibraryTab.entries.map { it.label }, tab.label, { label -> tab = LibraryTab.entries.first { it.label == label } })
        if (items.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(top = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(tab.emptyIcon, null, tint = Palette.muted, modifier = Modifier.size(36.dp))
            }
        } else {
            items.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    pair.forEach { art ->
                        LibraryTile(art, user.profile.completedLessons.contains(art.id), Modifier.weight(1f)) { onClose(); onOpen(art) }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}
