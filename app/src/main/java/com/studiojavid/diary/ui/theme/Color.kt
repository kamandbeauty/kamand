package com.studiojavid.diary.ui.theme

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
val DarkBackground = Color(0xFF141327)
val DarkSurface = Color(0xFF1E1D38)
val DarkSurfaceMuted = Color(0xFF282746)
val DarkOutline = Color(0x1FFFFFFF)
val DarkTextPrimary = Color(0xFFF3EFF8)
val DarkTextSecondary = Color(0xFFA9A2B8)

/**
 * Extra design tokens that Material 3 does not model, exposed through a
 * CompositionLocal so every screen reads the same values in light & dark.
 */
@Immutable
data class DiaryColors(
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
    val progressStart: Color,
    val progressEnd: Color,
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

/**
 * Builds the token set for a palette. Accent hues (yellow/mint/pink…) stay
 * shared across palettes so category colours remain recognisable, while the
 * structural colours follow the selected theme.
 */
fun diaryColorsOf(palette: ThemePalette, dark: Boolean): DiaryColors {
    val p = if (dark) palette.dark else palette.light
    val base = if (dark) DarkDiaryColors else LightDiaryColors
    return base.copy(
        isDark = dark,
        background = p.background,
        surface = p.surface,
        surfaceMuted = p.surfaceMuted,
        textPrimary = p.textPrimary,
        textSecondary = p.textSecondary,
        coral = p.primary,
        purple = p.secondary,
        orange = p.accent,
        gradientStart = p.gradientStart,
        gradientEnd = p.gradientEnd,
        progressStart = p.progressStart,
        progressEnd = p.progressEnd,
        priorityHigh = p.primary,
        priorityMedium = p.accent
    )
}

val LightDiaryColors = DiaryColors(
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
    progressStart = Coral,
    progressEnd = Purple,
    priorityLow = Turquoise,
    priorityMedium = Orange,
    priorityHigh = Coral,
    success = Mint,
    danger = Color(0xFFE86A6A)
)

val DarkDiaryColors = DiaryColors(
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
    gradientStart = Color(0xFF221F3D),
    gradientEnd = Color(0xFF17162B),
    progressStart = Color(0xFFFF8080),
    progressEnd = Color(0xFF9B84FF),
    priorityLow = Color(0xFF57D6EE),
    priorityMedium = Color(0xFFFFB067),
    priorityHigh = Color(0xFFFF8080),
    success = Color(0xFF4BD9AE),
    danger = Color(0xFFFF8585)
)

/**
 * A very subtle warm/cool shift applied to the page background depending on the
 * time of day (§13). The tint is intentionally tiny — it should register as
 * atmosphere, never as "the app changed colour".
 */
fun DiaryColors.timeOfDayGradient(hour: Int): List<Color> {
    val warm: Color
    val cool: Color
    when (hour) {
        in 5..10 -> { // morning: soft warm
            warm = Color(0xFFFFB27A); cool = Color(0xFFFFD9A0)
        }
        in 11..15 -> { // midday: neutral bright
            warm = Color(0xFFFFC97A); cool = Color(0xFF9AD7F5)
        }
        in 16..19 -> { // evening: orange → pink
            warm = Color(0xFFFF9A6C); cool = Color(0xFFFF8FB8)
        }
        else -> { // night: purple → blue
            warm = Color(0xFF8E7BFF); cool = Color(0xFF5C7CFF)
        }
    }
    val strength = if (isDark) 0.10f else 0.16f
    return listOf(
        blend(gradientStart, warm, strength),
        blend(gradientEnd, cool, strength * 0.6f),
        background
    )
}

private fun blend(base: Color, tint: Color, amount: Float) = Color(
    red = base.red + (tint.red - base.red) * amount,
    green = base.green + (tint.green - base.green) * amount,
    blue = base.blue + (tint.blue - base.blue) * amount,
    alpha = 1f
)
