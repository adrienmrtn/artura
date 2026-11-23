package com.vikstudios.artura.main

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.pressable
import com.vikstudios.artura.data.Artwork

/** "Thumbnail + title + chevron" row, reused on several screens (from TodayView.swift). */
@Composable
fun ArtworkRow(artwork: Artwork, done: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().pressable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ArtImage(artwork.image, Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)), small = true)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(artwork.title, style = AType.bodyStrong, color = Palette.ink)
            Text(artwork.meta, style = AType.caption, color = Palette.muted)
        }
        if (done) CheckBadge(Palette.green, 24.dp)
        else Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Palette.ink, modifier = Modifier.size(22.dp))
    }
}
