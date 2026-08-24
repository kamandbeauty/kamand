package com.modir.forushgah.core.designsystem.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes

val ModirShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp()),
    small = RoundedCornerShape(10.dp()),
    medium = RoundedCornerShape(16.dp()),
    large = RoundedCornerShape(22.dp()),
    extraLarge = RoundedCornerShape(28.dp()),
)

// Small helper so this file has no other imports to manage; kept private-ish via top-level fun.
private fun Int.dp() = androidx.compose.ui.unit.Dp(this.toFloat())
