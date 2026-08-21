package com.studiojavid.diary.ui.theme

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Color
import com.studiojavid.diary.R

/**
 * A full colour identity, not just a background tint: primary, secondary,
 * accent, card, progress and FAB colours all shift together.
 *
 * Every palette declares both a light and a dark variant so Dark Mode always
 * looks intentional.
 *
 * ### Extensibility (future Theme Store)
 * [tier] marks a palette as free or premium. The catalogue is a plain list, so
 * a future release can append remotely-fetched palettes and gate them on
 * [ThemeTier.PREMIUM] without touching any screen. No payment code lives here.
 */
enum class ThemeTier { FREE, PREMIUM }

data class PaletteColors(
    val primary: Color,
    val secondary: Color,
    val accent: Color,
    val progressStart: Color,
    val progressEnd: Color,
    val background: Color,
    val surface: Color,
    val surfaceMuted: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val gradientStart: Color,
    val gradientEnd: Color
)

enum class ThemePalette(
    val id: String,
    @StringRes val labelRes: Int,
    val emoji: String,
    val tier: ThemeTier,
    val light: PaletteColors,
    val dark: PaletteColors
) {
    /** The original DIARY identity — coral + purple on warm paper. */
    RAINBOW(
        id = "rainbow",
        labelRes = R.string.theme_rainbow,
        emoji = "🌈",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFFFF6B6B),
            secondary = Color(0xFF7C5CFF),
            accent = Color(0xFFFF9F45),
            progressStart = Color(0xFFFF6B6B),
            progressEnd = Color(0xFF7C5CFF),
            background = Color(0xFFFDF7F4),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFF6F1FA),
            textPrimary = Color(0xFF241F2E),
            textSecondary = Color(0xFF6C6579),
            gradientStart = Color(0xFFFFF1EA),
            gradientEnd = Color(0xFFF2ECFF)
        ),
        dark = PaletteColors(
            primary = Color(0xFFFF8080),
            secondary = Color(0xFF9B84FF),
            accent = Color(0xFFFFB067),
            progressStart = Color(0xFFFF8080),
            progressEnd = Color(0xFF9B84FF),
            background = Color(0xFF141327),
            surface = Color(0xFF1E1D38),
            surfaceMuted = Color(0xFF282746),
            textPrimary = Color(0xFFF3EFF8),
            textSecondary = Color(0xFFA9A2B8),
            gradientStart = Color(0xFF221F3D),
            gradientEnd = Color(0xFF17162B)
        )
    ),

    GREEN(
        id = "green",
        labelRes = R.string.theme_green,
        emoji = "🌿",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFF2FB37C),
            secondary = Color(0xFF5BC0A6),
            accent = Color(0xFFFFC93C),
            progressStart = Color(0xFF57C785),
            progressEnd = Color(0xFF2FB37C),
            background = Color(0xFFF5FAF5),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFEBF5EE),
            textPrimary = Color(0xFF1C2B24),
            textSecondary = Color(0xFF5F7168),
            gradientStart = Color(0xFFE9F7EC),
            gradientEnd = Color(0xFFF3FBF4)
        ),
        dark = PaletteColors(
            primary = Color(0xFF4CD69A),
            secondary = Color(0xFF74D8BE),
            accent = Color(0xFFFFD466),
            progressStart = Color(0xFF7BE3AE),
            progressEnd = Color(0xFF4CD69A),
            background = Color(0xFF101711),
            surface = Color(0xFF18211B),
            surfaceMuted = Color(0xFF1F2C25),
            textPrimary = Color(0xFFECF6EE),
            textSecondary = Color(0xFF9DB3A6),
            gradientStart = Color(0xFF17251C),
            gradientEnd = Color(0xFF121A15)
        )
    ),

    OCEAN(
        id = "ocean",
        labelRes = R.string.theme_ocean,
        emoji = "🌊",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFF2A9DD6),
            secondary = Color(0xFF31C8E6),
            accent = Color(0xFF7C5CFF),
            progressStart = Color(0xFF31C8E6),
            progressEnd = Color(0xFF2A6FD6),
            background = Color(0xFFF4F9FD),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFE8F2FA),
            textPrimary = Color(0xFF172733),
            textSecondary = Color(0xFF5C7182),
            gradientStart = Color(0xFFE5F4FC),
            gradientEnd = Color(0xFFEFF3FF)
        ),
        dark = PaletteColors(
            primary = Color(0xFF4FC3F0),
            secondary = Color(0xFF57D6EE),
            accent = Color(0xFF9B84FF),
            progressStart = Color(0xFF57D6EE),
            progressEnd = Color(0xFF5A8DF0),
            background = Color(0xFF0E151C),
            surface = Color(0xFF161F28),
            surfaceMuted = Color(0xFF1D2A35),
            textPrimary = Color(0xFFE9F3FA),
            textSecondary = Color(0xFF97AEBF),
            gradientStart = Color(0xFF14212B),
            gradientEnd = Color(0xFF101820)
        )
    ),

    PINK(
        id = "pink",
        labelRes = R.string.theme_pink,
        emoji = "🌸",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFFEE6FA6),
            secondary = Color(0xFFFF9EC4),
            accent = Color(0xFF9B6DFF),
            progressStart = Color(0xFFFF9EC4),
            progressEnd = Color(0xFFEE6FA6),
            background = Color(0xFFFEF6F9),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFFAECF3),
            textPrimary = Color(0xFF2E1F27),
            textSecondary = Color(0xFF7A6270),
            gradientStart = Color(0xFFFDEDF4),
            gradientEnd = Color(0xFFF7EEFF)
        ),
        dark = PaletteColors(
            primary = Color(0xFFFF8FBB),
            secondary = Color(0xFFFFB3D2),
            accent = Color(0xFFB795FF),
            progressStart = Color(0xFFFFB3D2),
            progressEnd = Color(0xFFFF8FBB),
            background = Color(0xFF1A1218),
            surface = Color(0xFF241A20),
            surfaceMuted = Color(0xFF30222B),
            textPrimary = Color(0xFFF8ECF2),
            textSecondary = Color(0xFFBCA3B0),
            gradientStart = Color(0xFF261A22),
            gradientEnd = Color(0xFF1D141A)
        )
    ),

    SUNSET(
        id = "sunset",
        labelRes = R.string.theme_sunset,
        emoji = "🌅",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFFF2743F),
            secondary = Color(0xFFFFA45B),
            accent = Color(0xFFE0518B),
            progressStart = Color(0xFFFFC93C),
            progressEnd = Color(0xFFF2743F),
            background = Color(0xFFFFF8F2),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFFBEDE2),
            textPrimary = Color(0xFF31211A),
            textSecondary = Color(0xFF7C665B),
            gradientStart = Color(0xFFFFEEDE),
            gradientEnd = Color(0xFFFFE9EC)
        ),
        dark = PaletteColors(
            primary = Color(0xFFFF9257),
            secondary = Color(0xFFFFBB7D),
            accent = Color(0xFFFF7BA8),
            progressStart = Color(0xFFFFD466),
            progressEnd = Color(0xFFFF9257),
            background = Color(0xFF1A1310),
            surface = Color(0xFF241B16),
            surfaceMuted = Color(0xFF32241C),
            textPrimary = Color(0xFFF9EDE4),
            textSecondary = Color(0xFFC0A697),
            gradientStart = Color(0xFF281C15),
            gradientEnd = Color(0xFF1D1511)
        )
    ),

    NIGHT(
        id = "night",
        labelRes = R.string.theme_night,
        emoji = "🌙",
        tier = ThemeTier.FREE,
        light = PaletteColors(
            primary = Color(0xFF5B5BD6),
            secondary = Color(0xFF8A7CFF),
            accent = Color(0xFF31C8E6),
            progressStart = Color(0xFF8A7CFF),
            progressEnd = Color(0xFF5B5BD6),
            background = Color(0xFFF6F6FC),
            surface = Color(0xFFFFFFFF),
            surfaceMuted = Color(0xFFECECF8),
            textPrimary = Color(0xFF1F1F33),
            textSecondary = Color(0xFF63637D),
            gradientStart = Color(0xFFEDEDFB),
            gradientEnd = Color(0xFFF4F1FF)
        ),
        dark = PaletteColors(
            primary = Color(0xFF8E8AFF),
            secondary = Color(0xFFA79CFF),
            accent = Color(0xFF57D6EE),
            progressStart = Color(0xFFA79CFF),
            progressEnd = Color(0xFF6E6AF0),
            background = Color(0xFF0D0D14),
            surface = Color(0xFF15151F),
            surfaceMuted = Color(0xFF1E1E2C),
            textPrimary = Color(0xFFEDEDF7),
            textSecondary = Color(0xFF9E9EB8),
            gradientStart = Color(0xFF161623),
            gradientEnd = Color(0xFF101018)
        )
    );

    companion object {
        val free: List<ThemePalette> get() = entries.filter { it.tier == ThemeTier.FREE }

        fun fromId(id: String?): ThemePalette = entries.firstOrNull { it.id == id } ?: RAINBOW
    }
}
