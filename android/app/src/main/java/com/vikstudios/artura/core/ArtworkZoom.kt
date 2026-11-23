package com.vikstudios.artura.core

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.vikstudios.artura.data.Artwork

// PLACEHOLDER — to be replaced by the port of ArtworkZoom.swift. Keep these signatures.

/** What the viewer shows: the picture, and a lighter version to display while the large one loads. */
data class ZoomTarget(val image: String, val placeholder: String? = null, val title: String? = null) {
    constructor(artwork: Artwork) : this(artwork.canvasImage, artwork.image, artwork.title)
}

/** A tap opens the painting full screen, where it can be zoomed (pinch, double tap, drag). */
fun Modifier.zoomable(artwork: Artwork): Modifier = this

/** Full-screen viewer; present it with `FullScreenCover`. */
@Composable fun ZoomViewer(target: ZoomTarget, onClose: () -> Unit) {}
