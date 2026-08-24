package com.modir.forushgah.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = PrimaryIndigo,
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = PrimaryIndigoLight,
    background = SurfaceLight,
    surface = SurfaceContainerLight,
    surfaceVariant = SurfaceVariantLight,
    outline = OutlineLight,
    onBackground = TextPrimaryLight,
    onSurface = TextPrimaryLight,
    onSurfaceVariant = TextSecondaryLight,
    error = ErrorRed,
    errorContainer = ErrorRedContainer,
)

private val DarkColors = darkColorScheme(
    primary = PrimaryIndigoLight,
    onPrimary = Color(0xFF0D1230),
    primaryContainer = PrimaryIndigoDark,
    background = SurfaceDark,
    surface = SurfaceContainerDark,
    surfaceVariant = SurfaceVariantDark,
    outline = OutlineDark,
    onBackground = TextPrimaryDark,
    onSurface = TextPrimaryDark,
    onSurfaceVariant = TextSecondaryDark,
    error = ErrorRed,
    errorContainer = ErrorRedContainer,
)

/** Semantic (success/warning/info) colors, exposed outside the standard M3 slots
 * since M3's default ColorScheme has no first-class slot for them. */
data class SemanticColors(
    val success: Color,
    val successContainer: Color,
    val warning: Color,
    val warningContainer: Color,
    val info: Color,
    val infoContainer: Color,
)

private val LightSemantic = SemanticColors(
    success = SuccessGreen, successContainer = SuccessGreenContainer,
    warning = WarningAmber, warningContainer = WarningAmberContainer,
    info = InfoBlue, infoContainer = InfoBlueContainer,
)

val LocalSemanticColors = staticCompositionLocalOf { LightSemantic }

@Composable
fun ModirTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColors else LightColors

    // App is RTL-first: force RTL layout direction regardless of device locale,
    // since the entire product is built for Persian-speaking store owners.
    CompositionLocalProvider(
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalSemanticColors provides LightSemantic,
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ModirTypography,
            shapes = ModirShapes,
            content = content,
        )
    }
}
