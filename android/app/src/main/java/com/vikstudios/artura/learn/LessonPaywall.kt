package com.vikstudios.artura.learn

import androidx.compose.runtime.Composable
import com.vikstudios.artura.data.Artwork

// PLACEHOLDER — to be replaced by the port of LessonPaywall.swift. Keep this signature.
@Composable fun LessonPaywall(
    artwork: Artwork, title: String, subtitle: String, closeTitle: String, closeDelay: Int = 0,
    onClose: () -> Unit, onUnlocked: () -> Unit,
) {}
