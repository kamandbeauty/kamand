package com.studiojavid.memory.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.sp
import com.studiojavid.memory.R

/** Vazirmatn is bundled locally so the app looks identical on every device. */
val Vazirmatn = FontFamily(
    Font(R.font.vazirmatn_regular, FontWeight.Normal),
    Font(R.font.vazirmatn_medium, FontWeight.Medium),
    Font(R.font.vazirmatn_semibold, FontWeight.SemiBold),
    Font(R.font.vazirmatn_bold, FontWeight.Bold)
)

private val lineHeightStyle = LineHeightStyle(
    alignment = LineHeightStyle.Alignment.Center,
    trim = LineHeightStyle.Trim.None
)

private fun style(size: Int, lineHeight: Int, weight: FontWeight, letterSpacing: Double = 0.0) = TextStyle(
    fontFamily = Vazirmatn,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = lineHeight.sp,
    letterSpacing = letterSpacing.sp,
    lineHeightStyle = lineHeightStyle
)

val MemoryTypography = Typography(
    displaySmall = style(34, 46, FontWeight.Bold),
    headlineLarge = style(28, 40, FontWeight.Bold),
    headlineMedium = style(24, 34, FontWeight.Bold),
    headlineSmall = style(20, 30, FontWeight.SemiBold),
    titleLarge = style(18, 28, FontWeight.SemiBold),
    titleMedium = style(16, 26, FontWeight.SemiBold),
    titleSmall = style(14, 22, FontWeight.Medium),
    bodyLarge = style(16, 26, FontWeight.Normal),
    bodyMedium = style(14, 24, FontWeight.Normal),
    bodySmall = style(13, 21, FontWeight.Normal),
    labelLarge = style(14, 20, FontWeight.SemiBold),
    labelMedium = style(12, 18, FontWeight.Medium),
    labelSmall = style(11, 16, FontWeight.Medium)
)
