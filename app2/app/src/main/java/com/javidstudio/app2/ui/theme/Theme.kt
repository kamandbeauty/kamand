package com.javidstudio.app2.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.data.prefs.ThemeMode

val LocalApp2Colors = staticCompositionLocalOf { LightApp2Colors }

object App2Theme {
    val colors: App2Colors
        @Composable get() = LocalApp2Colors.current
}

val App2Shapes = Shapes(
    extraSmall = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
    small = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
    extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(32.dp)
)

@Composable
fun App2Theme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    palette: ThemePalette = ThemePalette.RAINBOW,
    content: @Composable () -> Unit
) {
    val dark = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val tokens = app2ColorsOf(palette, dark)

    // Crossfade the main surfaces when the theme flips.
    val animSpec = tween<Color>(durationMillis = 420)
    val background by animateColorAsState(tokens.background, animSpec, label = "bg")
    val surface by animateColorAsState(tokens.surface, animSpec, label = "surface")
    val onSurface by animateColorAsState(tokens.textPrimary, animSpec, label = "onSurface")

    val scheme = if (dark) {
        darkColorScheme(
            primary = tokens.coral,
            onPrimary = Color(0xFF2A1616),
            primaryContainer = tokens.coral.copy(alpha = 0.22f),
            onPrimaryContainer = tokens.coral,
            secondary = tokens.purple,
            onSecondary = Color(0xFF17122B),
            tertiary = tokens.turquoise,
            background = background,
            onBackground = onSurface,
            surface = surface,
            onSurface = onSurface,
            surfaceVariant = tokens.surfaceMuted,
            onSurfaceVariant = tokens.textSecondary,
            outline = tokens.textSecondary.copy(alpha = 0.4f),
            outlineVariant = tokens.outline,
            error = tokens.danger
        )
    } else {
        lightColorScheme(
            primary = tokens.coral,
            onPrimary = Color.White,
            primaryContainer = tokens.coral.copy(alpha = 0.14f),
            onPrimaryContainer = Color(0xFF8E2E2E),
            secondary = tokens.purple,
            onSecondary = Color.White,
            tertiary = tokens.turquoise,
            background = background,
            onBackground = onSurface,
            surface = surface,
            onSurface = onSurface,
            surfaceVariant = tokens.surfaceMuted,
            onSurfaceVariant = tokens.textSecondary,
            outline = tokens.textSecondary.copy(alpha = 0.35f),
            outlineVariant = tokens.outline,
            error = tokens.danger
        )
    }

    CompositionLocalProvider(LocalApp2Colors provides tokens) {
        MaterialTheme(
            colorScheme = scheme,
            typography = App2Typography,
            shapes = App2Shapes,
            content = content
        )
    }
}
