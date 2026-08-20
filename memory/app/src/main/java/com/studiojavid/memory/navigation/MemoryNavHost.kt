package com.studiojavid.memory.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.automirrored.rounded.StickyNote2
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector
import com.studiojavid.memory.R

enum class TopLevelDestination(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector
) {
    TODAY("today", R.string.nav_today, Icons.Rounded.WbSunny),
    CALENDAR("calendar", R.string.nav_calendar, Icons.Rounded.CalendarMonth),
    NOTES("notes", R.string.nav_notes, Icons.AutoMirrored.Rounded.StickyNote2),
    PROFILE("profile", R.string.nav_profile, Icons.Rounded.Person);

    companion object {
        fun fromRoute(route: String?): TopLevelDestination? = entries.firstOrNull { it.route == route }
    }
}

object Routes {
    const val SEARCH = "search"
    const val BIRTHDAYS = "birthdays"
    const val BIRTHDAY_PERSON = "birthday_person"
    const val BIRTHDAY_MESSAGES = "birthday_messages"
}
