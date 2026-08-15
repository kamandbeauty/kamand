package com.roozi.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

// --------------------------------------------------------------------------
// Brand palette — cheerful but never neon.
// --------------------------------------------------------------------------
val Coral = Color(0xFFFF6B6B)
val CoralSoft = Color(0xFFFF8A8A)
val Orange = Color(0xFFFF9F45)
val Yellow = Color(0xFFFFC93C)
val Mint = Color(0xFF2ECC9B)
val Turquoise = Color(0xFF31C8E6)
val Purple = Color(0xFF7C5CFF)
val Pink = Color(0xFFFF7EB6)

// Light surfaces — warm, calm paper
val LightBackground = Color(0xFFFDF7F4)
val LightSurface = Color(0xFFFFFFFF)
val LightSurfaceMuted = Color(0xFFF6F1FA)
val LightOutline = Color(0x14000000)
val LightTextPrimary = Color(0xFF241F2E)
val LightTextSecondary = Color(0xFF6C6579)

// Dark surfaces — deep plum rather than pure black so colors stay lively
val DarkBackground = Color(0xFF14131A)
val DarkSurface = Color(0xFF1E1C26)
val DarkSurfaceMuted = Color(0xFF262433)
val DarkOutline = Color(0x1FFFFFFF)
val DarkTextPrimary = Color(0xFFF3EFF8)
val DarkTextSecondary = Color(0xFFA9A2B8)

/**
 * Extra design tokens that Material 3 does not model, exposed through a
 * CompositionLocal so every screen reads the same values in light & dark.
 */
@Immutable
data class RooziColors(
    val isDark: Boolean,
    val background: Color,
    val surface: Color,
    val surfaceMuted: Color,
    val outline: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val coral: Color,
    val orange: Color,
    val yellow: Color,
    val mint: Color,
    val turquoise: Color,
    val purple: Color,
    val pink: Color,
    val gradientStart: Color,
    val gradientEnd: Color,
    val priorityLow: Color,
    val priorityMedium: Color,
    val priorityHigh: Color,
    val success: Color,
    val danger: Color
) {
    /** Softened version of a category/accent color suitable for chip fills. */
    fun tint(color: Color): Color = color.copy(alpha = if (isDark) 0.22f else 0.14f)

    /** Readable on-tint content color. */
    fun onTint(color: Color): Color = if (isDark) lighten(color, 0.25f) else darken(color, 0.18f)
}

private fun lighten(color: Color, amount: Float): Color = Color(
    red = color.red + (1f - color.red) * amount,
    green = color.green + (1f - color.green) * amount,
    blue = color.blue + (1f - color.blue) * amount,
    alpha = color.alpha
)

private fun darken(color: Color, amount: Float): Color = Color(
    red = color.red * (1f - amount),
    green = color.green * (1f - amount),
    blue = color.blue * (1f - amount),
    alpha = color.alpha
)

val LightRooziColors = RooziColors(
    isDark = false,
    background = LightBackground,
    surface = LightSurface,
    surfaceMuted = LightSurfaceMuted,
    outline = LightOutline,
    textPrimary = LightTextPrimary,
    textSecondary = LightTextSecondary,
    coral = Coral,
    orange = Orange,
    yellow = Yellow,
    mint = Mint,
    turquoise = Turquoise,
    purple = Purple,
    pink = Pink,
    gradientStart = Color(0xFFFFF1EA),
    gradientEnd = Color(0xFFF2ECFF),
    priorityLow = Turquoise,
    priorityMedium = Orange,
    priorityHigh = Coral,
    success = Mint,
    danger = Color(0xFFE86A6A)
)

val DarkRooziColors = RooziColors(
    isDark = true,
    background = DarkBackground,
    surface = DarkSurface,
    surfaceMuted = DarkSurfaceMuted,
    outline = DarkOutline,
    textPrimary = DarkTextPrimary,
    textSecondary = DarkTextSecondary,
    coral = Color(0xFFFF8080),
    orange = Color(0xFFFFB067),
    yellow = Color(0xFFFFD466),
    mint = Color(0xFF4BD9AE),
    turquoise = Color(0xFF57D6EE),
    purple = Color(0xFF9B84FF),
    pink = Color(0xFFFF97C4),
    gradientStart = Color(0xFF221E2E),
    gradientEnd = Color(0xFF191824),
    priorityLow = Color(0xFF57D6EE),
    priorityMedium = Color(0xFFFFB067),
    priorityHigh = Color(0xFFFF8080),
    success = Color(0xFF4BD9AE),
    danger = Color(0xFFFF8585)
)
