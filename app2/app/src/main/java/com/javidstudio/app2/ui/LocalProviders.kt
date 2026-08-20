package com.javidstudio.app2.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.javidstudio.app2.core.date.DateFormatter
import com.javidstudio.app2.data.repo.Category
import com.javidstudio.app2.data.repo.DefaultCategories

val LocalDateFormatter = compositionLocalOf<DateFormatter> {
    error("DateFormatter not provided")
}

@Composable
fun rememberDateFormatter(persian: Boolean): DateFormatter {
    val context = LocalContext.current
    return remember(context, persian) { DateFormatter(context, persian) }
}

/** Built-in categories are localized; custom ones use the user's own text. */
@Composable
fun Category.displayName(): String {
    val res = DefaultCategories.labelRes(builtInKey)
    return if (res != null) stringResource(res) else rawName
}
