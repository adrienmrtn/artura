package com.vikstudios.artura.core

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.vikstudios.artura.R

// MARK: - Colors (same values as Theme.swift)

fun hexColor(hex: Long, alpha: Float = 1f): Color =
    Color(((hex shr 16) and 0xFF).toInt(), ((hex shr 8) and 0xFF).toInt(), (hex and 0xFF).toInt(), (alpha * 255).toInt())

/** "#RRGGBB" → Color. Gray if the string is invalid. */
fun hexColor(hex: String): Color {
    val cleaned = hex.trim().trimStart('#').trim()
    val value = cleaned.toLongOrNull(16) ?: 0x888888
    return hexColor(value)
}

/**
 * Colors of the app. Each one has a light and a dark value; `isDark` (set from the system appearance
 * in MainActivity) is state, so every screen redraws when it changes.
 */
object Palette {
    var isDark by mutableStateOf(false)

    private fun pick(light: Long, dark: Long) = if (isDark) hexColor(dark) else hexColor(light)

    /** Screen background: plain white (warm near-black in dark mode). */
    val bg: Color get() = pick(0xFFFFFF, 0x141312)
    val ink: Color get() = pick(0x2D2C2B, 0xF3EFEC)
    val muted: Color get() = pick(0x5C5753, 0xACA59F)
    /** Cards and rows laid on the background: very light warm greys. */
    val card: Color get() = pick(0xF9F4F2, 0x201E1C)
    val line: Color get() = pick(0xEFE8E3, 0x2E2B29)
    val lip: Color get() = pick(0xE4DAD4, 0x3B3734)
    /** Bright blue: buttons, selection, links. */
    val blue: Color get() = pick(0x0061EF, 0x2B78FF)
    val blueDark: Color get() = pick(0x0045B5, 0x1A52BE)
    val blueText: Color get() = pick(0x0050C8, 0x75AEFF)
    /** Pale tints of the blue, for insets and selected answers. */
    val mist: Color get() = pick(0xDCEBFF, 0x182A4D)
    val mistLight: Color get() = pick(0xEAF2FF, 0x121E36)
    val sky: Color get() = pick(0x0B74E5, 0x0B74E5)
    val skyLight: Color get() = pick(0x4D9DF2, 0x4D9DF2)
    val cloud: Color get() = pick(0xFFD3E4, 0x4C2536)
    val yellow: Color get() = pick(0xFFB000, 0xFFB000)
    val orange: Color get() = pick(0xFF6800, 0xFF7A1F)
    val pink: Color get() = pick(0xFF8FBC, 0xFF8FBC)
    val green: Color get() = pick(0x00804A, 0x3CC98A)
    val greenSoft: Color get() = pick(0xE3F6EA, 0x12301F)
    val red: Color get() = pick(0xB3261E, 0xFF6B61)
    val redSoft: Color get() = pick(0xFCE8E6, 0x3B1816)
}

// MARK: - Typography (Figtree, embedded in the app)

val Figtree = FontFamily(
    Font(R.font.figtree_regular, FontWeight.Normal),
    Font(R.font.figtree_medium, FontWeight.Medium),
    Font(R.font.figtree_semibold, FontWeight.SemiBold),
    Font(R.font.figtree_bold, FontWeight.Bold),
)

/** Figtree at a size in points (sp), like `.figtree(size, weight)` on iOS. */
fun figtree(size: Float, weight: FontWeight = FontWeight.Normal): TextStyle =
    TextStyle(fontFamily = Figtree, fontWeight = weight, fontSize = size.sp, lineHeight = (size * 1.25f).sp)

fun figtree(size: Int, weight: FontWeight = FontWeight.Normal): TextStyle = figtree(size.toFloat(), weight)

/** System serif, reserved for quotes. */
fun serif(size: Float, weight: FontWeight = FontWeight.Medium): TextStyle =
    TextStyle(fontFamily = FontFamily.Serif, fontWeight = weight, fontSize = size.sp, lineHeight = (size * 1.3f).sp)

object AType {
    val title = figtree(30, FontWeight.SemiBold)
    val titleSmall = figtree(26, FontWeight.SemiBold)
    val heading = figtree(20, FontWeight.SemiBold)
    val cardTitle = figtree(18, FontWeight.SemiBold)
    val body = figtree(16)
    val bodyStrong = figtree(16, FontWeight.SemiBold)
    val small = figtree(14)
    val caption = figtree(13)
}

val TextUnit.asFloat: Float get() = value

// MARK: - Shapes

/** Header area whose bottom edge is a slightly tilted arc. */
object ArcHeaderShape : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val k = density.density
        val p = Path().apply {
            moveTo(0f, 0f)
            lineTo(size.width, 0f)
            lineTo(size.width, size.height - 26 * k)
            quadraticTo(size.width * 0.487f, size.height - 74 * k, 0f, size.height - 16 * k)
            close()
        }
        return Outline.Generic(p)
    }
}

/** Bottom-of-screen panel whose top edge is a tilted arc. */
object ArcTopShape : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val k = density.density
        val p = Path().apply {
            moveTo(0f, 0f)
            quadraticTo(size.width * 0.51f, 34 * k, size.width, 8 * k)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        return Outline.Generic(p)
    }
}

// MARK: - Animations (simple curves, no spring: no bounce)

object Anim {
    val glideEasing = CubicBezierEasing(0.22f, 1f, 0.36f, 1f)
    fun <T> snappy() = tween<T>(160, easing = LinearOutSlowInEasing)
    fun <T> gentle() = tween<T>(240, easing = FastOutSlowInEasing)
    fun <T> bouncy() = tween<T>(200, easing = LinearOutSlowInEasing)
    /** Slide between two screens: quick start, very soft landing. */
    fun <T> glide() = tween<T>(550, easing = glideEasing)
    /** An element entering the screen. */
    fun <T> settle() = tween<T>(600, easing = glideEasing)
}
