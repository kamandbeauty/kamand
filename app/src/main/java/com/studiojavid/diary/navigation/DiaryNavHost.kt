package com.studiojavid.diary.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.StickyNote2
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Cake
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Person
import androidx.compose.ui.graphics.vector.ImageVector
import com.studiojavid.diary.R

enum class TopLevelDestination(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector
) {
    DIARY("diary", R.string.nav_diary, Icons.Rounded.AutoStories),
    CALENDAR("calendar", R.string.nav_calendar, Icons.Rounded.CalendarMonth),
    BIRTHDAYS("birthdays", R.string.nav_birthdays, Icons.Rounded.Cake),
    NOTES("notes", R.string.nav_notes, Icons.AutoMirrored.Rounded.StickyNote2),
    PROFILE("profile", R.string.nav_profile, Icons.Rounded.Person);

    companion object {
        fun fromRoute(route: String?): TopLevelDestination? =
            entries.firstOrNull { it.route == route }
    }
}

object Routes {
    const val SEARCH = "search"

    /**
     * Birthdays is a tab of its own now, so only the screens *below* it are
     * plain routes. The list route lives on [TopLevelDestination.BIRTHDAYS].
     */
    const val BIRTHDAY_PERSON = "birthday_person"
    const val BIRTHDAY_MESSAGES = "birthday_messages"
}
