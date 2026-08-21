package com.studiojavid.diary.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.studiojavid.diary.core.date.DateFormatter

val LocalDateFormatter = compositionLocalOf<DateFormatter> {
    error("DateFormatter not provided")
}

@Composable
fun rememberDateFormatter(persian: Boolean): DateFormatter {
    val context = LocalContext.current
    return remember(context, persian) { DateFormatter(context, persian) }
}
