package com.vikstudios.artura.onboarding

import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// PLACEHOLDER — to be replaced by the port of OnboardingSetup.swift. Keep these signatures: other files use them.

@Composable fun ReminderScreen(onNext: () -> Unit) {}
@Composable fun WidgetScreen(onNext: () -> Unit) {}
@Composable fun LoadingScreen(onNext: () -> Unit) {}
@Composable fun PlanScreen(onNext: () -> Unit) {}
@Composable fun SocialProofScreen(onNext: () -> Unit) {}
@Composable fun AccountScreen(onBack: () -> Unit, onNext: () -> Unit) {}

/** Row of the five avatars (used in the onboarding and the profile). */
@Composable fun AvatarPicker(selection: Int, onSelect: (Int) -> Unit, size: Dp = 56.dp, onPick: (() -> Unit)? = null) {}

/** "Continue with Google" (+ message on failure). Used in the onboarding and in the profile's settings. */
@Composable fun SignInButtons(message: String?, onMessage: (String?) -> Unit, onDone: () -> Unit) {}
