package ir.factoryar.core.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.core.graphics.ColorUtils
import ir.factoryar.core.domain.repository.ThemePreset

/** رنگ‌های بذر (Seed) تم‌های آماده */
object ThemeSeeds {
    val seeds: Map<ThemePreset, Long> = mapOf(
        ThemePreset.CLASSIC_BLUE to 0xFF1E5AA8,
        ThemePreset.FINANCE_GREEN to 0xFF0E7A4F,
        ThemePreset.MODERN_PURPLE to 0xFF6D4BC0,
        ThemePreset.WARM_ORANGE to 0xFFD96A1F,
        ThemePreset.MINIMAL_GRAY to 0xFF54606E,
    )

    fun seedFor(preset: ThemePreset): Long = seeds[preset] ?: 0xFF1E5AA8
}

/**
 * مشتق‌سازی ColorScheme کامل از یک رنگ بذر، با رویکرد تونالِ Material You (ساده‌شده با HSL).
 * رنگ‌های secondary/tertiary و سطوح به‌صورت خودکار از همان بذر ساخته می‌شوند.
 */
object ColorSchemeFactory {

    private fun hsl(seed: Int): FloatArray =
        FloatArray(3).also { ColorUtils.colorToHSL(seed, it) }

    private fun color(h: Float, s: Float, l: Float): Color =
        Color(ColorUtils.HSLToColor(floatArrayOf((h % 360 + 360) % 360, s.coerceIn(0f, 1f), l.coerceIn(0f, 1f))))

    /** رنگ نوشته/آیکن خوانا روی seed */
    private fun contentOn(base: Int): Color {
        val hsl = hsl(base)
        return if (hsl[2] > 0.55f) Color(0xFF1B1B1F) else Color(0xFFFFFFFF)
    }

    fun lightFromSeed(seedArgb: Int): ColorScheme {
        val (h, s) = hsl(seedArgb).let { it[0] to it[1] }
        val ss = s.coerceIn(0.28f, 0.85f)
        val seed = color(h, ss, 0.42f).toArgb()

        return lightColorScheme(
            primary = color(h, ss, 0.42f),
            onPrimary = contentOn(seed),
            primaryContainer = color(h, ss * 0.75f, 0.90f),
            onPrimaryContainer = color(h, (ss * 1.1f).coerceAtMost(1f), 0.22f),
            secondary = color(h + 22f, ss * 0.55f, 0.42f),
            onSecondary = Color(0xFFFFFFFF),
            secondaryContainer = color(h + 22f, ss * 0.4f, 0.90f),
            onSecondaryContainer = color(h + 22f, ss * 0.7f, 0.22f),
            tertiary = color(h + 55f, ss * 0.5f, 0.40f),
            onTertiary = Color(0xFFFFFFFF),
            tertiaryContainer = color(h + 55f, ss * 0.35f, 0.90f),
            onTertiaryContainer = color(h + 55f, ss * 0.65f, 0.22f),
            background = color(h, ss * 0.10f, 0.985f),
            onBackground = color(h, ss * 0.15f, 0.12f),
            surface = color(h, ss * 0.10f, 0.985f),
            onSurface = color(h, ss * 0.15f, 0.12f),
            surfaceVariant = color(h, ss * 0.14f, 0.92f),
            onSurfaceVariant = color(h, ss * 0.2f, 0.35f),
            surfaceTint = Color(seed),
            inverseSurface = color(h, ss * 0.12f, 0.18f),
            inverseOnSurface = color(h, ss * 0.08f, 0.95f),
            inversePrimary = color(h, ss, 0.80f),
            outline = color(h, ss * 0.12f, 0.55f),
            outlineVariant = color(h, ss * 0.10f, 0.82f),
            error = Color(0xFFBA1A1A),
            onError = Color(0xFFFFFFFF),
            errorContainer = Color(0xFFFFDAD6),
            onErrorContainer = Color(0xFF410002),
        )
    }

    fun darkFromSeed(seedArgb: Int): ColorScheme {
        val (h, s) = hsl(seedArgb).let { it[0] to it[1] }
        val ss = s.coerceIn(0.28f, 0.85f)

        return darkColorScheme(
            primary = color(h, ss, 0.78f),
            onPrimary = color(h, (ss * 1.2f).coerceAtMost(1f), 0.18f),
            primaryContainer = color(h, ss, 0.30f),
            onPrimaryContainer = color(h, ss * 0.7f, 0.90f),
            secondary = color(h + 22f, ss * 0.5f, 0.78f),
            onSecondary = color(h + 22f, ss * 0.8f, 0.18f),
            secondaryContainer = color(h + 22f, ss * 0.45f, 0.28f),
            onSecondaryContainer = color(h + 22f, ss * 0.35f, 0.90f),
            tertiary = color(h + 55f, ss * 0.45f, 0.78f),
            onTertiary = color(h + 55f, ss * 0.7f, 0.18f),
            tertiaryContainer = color(h + 55f, ss * 0.4f, 0.28f),
            onTertiaryContainer = color(h + 55f, ss * 0.3f, 0.90f),
            background = color(h, ss * 0.12f, 0.09f),
            onBackground = color(h, ss * 0.10f, 0.90f),
            surface = color(h, ss * 0.12f, 0.09f),
            onSurface = color(h, ss * 0.10f, 0.90f),
            surfaceVariant = color(h, ss * 0.14f, 0.22f),
            onSurfaceVariant = color(h, ss * 0.16f, 0.78f),
            surfaceTint = color(h, ss, 0.78f),
            inverseSurface = color(h, ss * 0.08f, 0.90f),
            inverseOnSurface = color(h, ss * 0.15f, 0.18f),
            inversePrimary = color(h, ss, 0.40f),
            outline = color(h, ss * 0.10f, 0.60f),
            outlineVariant = color(h, ss * 0.12f, 0.30f),
            error = Color(0xFFFFB4AB),
            onError = Color(0xFF690005),
            errorContainer = Color(0xFF93000A),
            onErrorContainer = Color(0xFFFFDAD6),
        )
    }

    fun build(seedArgb: Long, dark: Boolean): ColorScheme {
        val seed = seedArgb.toInt()
        return if (dark) darkFromSeed(seed) else lightFromSeed(seed)
    }
}
