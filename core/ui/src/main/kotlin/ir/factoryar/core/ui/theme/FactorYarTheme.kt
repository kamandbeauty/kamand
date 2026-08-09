package ir.factoryar.core.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.domain.repository.ThemeMode
import ir.factoryar.core.domain.repository.ThemePreset

/** واحد پول فعلی اپ — در ریشه Coposition تزریق می‌شود */
val LocalCurrencyUnit = compositionLocalOf { CurrencyUnit.TOMAN }

/** آیا کاربر اشتراک طلایی دارد (برای نمایش/گیت قابلیت‌ها در UI) */
val LocalIsPremium = compositionLocalOf { false }

/**
 * فونت وزیرمتن:
 * فایل‌های vazirmatn_regular.ttf / vazirmatn_medium.ttf / vazirmatn_bold.ttf را
 * در core/ui/src/main/res/font قرار دهید (پروانه SIL OFL) و resources زیر را فعال کنید.
 * تا پیش از آن، فونت پیش‌فرض سیستم استفاده می‌شود.
 */
val FyFontFamily = FontFamily.Default

val FyTypography = Typography(
    displaySmall = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Bold, fontSize = 28.sp, lineHeight = 40.sp),
    headlineSmall = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp, lineHeight = 32.sp),
    titleLarge = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Bold, fontSize = 19.sp, lineHeight = 28.sp),
    titleMedium = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 24.sp),
    titleSmall = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp),
    bodyLarge = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 26.sp),
    bodyMedium = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 22.sp),
    bodySmall = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp),
    labelMedium = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp),
    labelSmall = TextStyle(fontFamily = FyFontFamily, fontWeight = FontWeight.Medium, fontSize = 10.sp, lineHeight = 14.sp),
)

@Composable
fun FactorYarTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    themePreset: ThemePreset = ThemePreset.CLASSIC_BLUE,
    customPrimaryArgb: Long = 0xFF1E5AA8,
    currencyUnit: CurrencyUnit = CurrencyUnit.TOMAN,
    isPremium: Boolean = false,
    content: @Composable () -> Unit,
) {
    val dark = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val seed = if (themePreset == ThemePreset.CUSTOM) customPrimaryArgb else ThemeSeeds.seedFor(themePreset)
    val scheme = ColorSchemeFactory.build(seed, dark)

    CompositionLocalProvider(
        LocalCurrencyUnit provides currencyUnit,
        LocalIsPremium provides isPremium,
        LocalLayoutDirection provides LayoutDirection.Rtl,
    ) {
        MaterialTheme(
            colorScheme = scheme,
            typography = FyTypography,
            shapes = FyShapes,
            content = content,
        )
    }
}

val FyShapes = androidx.compose.material3.Shapes(
    extraSmall = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
    small = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(20.dp),
    extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(28.dp),
)
