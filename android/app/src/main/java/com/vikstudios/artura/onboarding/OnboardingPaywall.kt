package com.vikstudios.artura.onboarding

import androidx.compose.runtime.Composable
import com.vikstudios.artura.services.TrialOffer

// PLACEHOLDER — to be replaced by the port of OnboardingPaywall.swift. Keep these signatures: other files use them.

@Composable fun GiftScreen(offer: TrialOffer, onNext: () -> Unit) {}
@Composable fun TrialNotifScreen(offer: TrialOffer, reminder: Boolean, onReminderChange: (Boolean) -> Unit, onNext: () -> Unit) {}
@Composable fun TrialTimelineScreen(offer: TrialOffer, onNext: () -> Unit) {}
@Composable fun TrialScreen(offer: TrialOffer, extendedOffer: TrialOffer?, reminder: Boolean, onFinish: () -> Unit) {}

/** The Artura Pro paywall opened from the app (feed, profile). Present it in a FullScreenCover. */
@Composable fun PaywallScreen(onClose: () -> Unit) {}
