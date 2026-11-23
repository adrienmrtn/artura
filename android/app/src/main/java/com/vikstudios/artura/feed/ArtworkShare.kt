package com.vikstudios.artura.feed

import android.content.Context
import com.vikstudios.artura.data.Artwork

// PLACEHOLDER — to be replaced by the port of ArtworkShare.swift. Keep these signatures.

/** Links used when sharing. The Play Store address is unknown until the app is published. */
object AppLinks {
    /** Play Store page of the app, added to shared messages once it exists. */
    val playStore: String? = null
    /** Address that receives suggestions. Empty: the "Suggest an idea" row is hidden. */
    const val supportEmail = "support@vikstudios.com"
}

/** Opens the system share sheet for an artwork (its image, with a short message). */
fun shareArtwork(context: Context, artwork: Artwork) {}
