package com.vikstudios.artura.learn

import androidx.compose.runtime.Composable
import com.vikstudios.artura.data.Artwork
import com.vikstudios.artura.data.LessonBlock

// PLACEHOLDER — to be replaced by the port of LessonView.swift. Keep this signature (used by CourseFlow and the onboarding).

/**
 * Reads a lesson block by block. In the app: `freeTaps` limits a free reader (null = no limit) and
 * `onBlocked` opens the paywall. In the onboarding: `pill`, `blocks` (the preview), `finishTitle`, `onSkip`.
 */
@Composable fun LessonView(
    artwork: Artwork,
    onBack: () -> Unit,
    onFinish: () -> Unit,
    freeTaps: Int? = null,
    onBlocked: () -> Unit = {},
    pill: String? = null,
    blocks: List<LessonBlock>? = null,
    finishTitle: String? = null,
    onSkip: (() -> Unit)? = null,
) {}
