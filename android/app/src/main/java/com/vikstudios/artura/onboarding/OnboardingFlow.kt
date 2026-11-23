package com.vikstudios.artura.onboarding

import androidx.compose.runtime.Composable
import com.vikstudios.artura.app.AppDebug
import com.vikstudios.artura.data.Profile
import com.vikstudios.artura.services.TrialOffer

// PLACEHOLDER — to be replaced by the port of OnboardingFlow.swift (OnbStep, OnboardingFlow).

@Composable fun OnboardingFlow() {}

object OnboardingDebug {
    val isDebug: Boolean get() = AppDebug.isDebug
    fun flag(key: String) = AppDebug.flag(key)
    fun int(key: String) = AppDebug.int(key)
    fun string(key: String) = AppDebug.string(key)
    /** Sample offer, to view the trial screens without a loaded Play product. */
    fun previewOffer(days: Int): TrialOffer? = if (flag("onbPreviewOffer")) TrialOffer.preview(days) else null
    /** Prepares a sample profile when a screen is opened directly. */
    fun prepare(profile: Profile): Profile = if (AppDebug.flag("skipOnboarding")) profile.copy(onboarded = true) else profile
}
