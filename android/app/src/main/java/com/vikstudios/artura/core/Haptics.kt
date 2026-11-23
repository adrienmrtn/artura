package com.vikstudios.artura.core

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Haptic feedback used throughout the app (same moments as on iOS). */
object Haptics {
    private var vibrator: Vibrator? = null

    fun init(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun predefined(effect: Int, fallbackMs: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        try {
            if (Build.VERSION.SDK_INT >= 29) v.vibrate(VibrationEffect.createPredefined(effect))
            else v.vibrate(VibrationEffect.createOneShot(fallbackMs, amplitude))
        } catch (_: Exception) {}
    }

    private fun oneShot(ms: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        try {
            val amp = if (v.hasAmplitudeControl()) amplitude.coerceIn(1, 255) else VibrationEffect.DEFAULT_AMPLITUDE
            v.vibrate(VibrationEffect.createOneShot(ms, amp))
        } catch (_: Exception) {}
    }

    private fun waveform(timings: LongArray, amplitudes: IntArray) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        try {
            if (v.hasAmplitudeControl()) v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            else v.vibrate(VibrationEffect.createWaveform(timings, -1))
        } catch (_: Exception) {}
    }

    fun tap() = predefined(VibrationEffect.EFFECT_TICK, 10, 80)
    fun press() = predefined(VibrationEffect.EFFECT_CLICK, 15, 140)
    fun soft() = oneShot(12, 60)
    fun rigid() = oneShot(8, 150)
    /** Barely perceptible vibration (a word appearing, an ignored tap). */
    fun whisper() = oneShot(6, 30)
    /** Variable-intensity vibration (0 to 1), for gradual build-ups. */
    fun rise(intensity: Double) = oneShot(10, (40 + intensity.coerceIn(0.0, 1.0) * 215).toInt())
    fun heavy() = predefined(VibrationEffect.EFFECT_HEAVY_CLICK, 25, 255)
    fun selection() = predefined(VibrationEffect.EFFECT_TICK, 8, 70)
    fun success() = waveform(longArrayOf(0, 18, 70, 28), intArrayOf(0, 120, 0, 200))
    fun warning() = waveform(longArrayOf(0, 25, 90, 25), intArrayOf(0, 180, 0, 120))
    fun error() = waveform(longArrayOf(0, 20, 60, 20, 60, 30), intArrayOf(0, 200, 0, 200, 0, 255))
}
