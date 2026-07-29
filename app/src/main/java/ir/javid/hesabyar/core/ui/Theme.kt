package ir.javid.hesabyar.core.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val AppTypography = Typography()

private val LightColors = lightColorScheme(
    primary = Color(0xFF006B5C), onPrimary = Color.White,
    primaryContainer = Color(0xFFA2F2DB), onPrimaryContainer = Color(0xFF002019),
    secondary = Color(0xFF4C635C), onSecondary = Color.White,
    secondaryContainer = Color(0xFFCFE9DE), onSecondaryContainer = Color(0xFF092019),
    tertiary = Color(0xFF765A00), onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFE08B), onTertiaryContainer = Color(0xFF251A00),
    background = Color(0xFFF8FAF8), onBackground = Color(0xFF191C1B),
    surface = Color(0xFFF8FAF8), onSurface = Color(0xFF191C1B),
    surfaceVariant = Color(0xFFDBE5DF), onSurfaceVariant = Color(0xFF404944),
    error = Color(0xFFBA1A1A), onError = Color.White
)
private val DarkColors = darkColorScheme(
    primary = Color(0xFF86D6C0), onPrimary = Color(0xFF00382E),
    primaryContainer = Color(0xFF005143), onPrimaryContainer = Color(0xFFA2F2DB),
    secondary = Color(0xFFB3CCC1), onSecondary = Color(0xFF1E352D),
    tertiary = Color(0xFFF2C34D), onTertiary = Color(0xFF3D2E00),
    background = Color(0xFF101413), onBackground = Color(0xFFE0E3E0),
    surface = Color(0xFF101413), onSurface = Color(0xFFE0E3E0)
)

@Composable
fun HesabyarTheme(content: @Composable () -> Unit) = MaterialTheme(colorScheme = LightColors, typography = AppTypography, content = content)
