package com.roozi.app.ui.birthday

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.roozi.app.R
import com.roozi.app.core.date.JalaliDate
import com.roozi.app.data.repo.BirthdayPerson
import com.roozi.app.ui.BirthdayViewModel
import com.roozi.app.ui.LocalDateFormatter
import com.roozi.app.ui.components.EmptyState
import com.roozi.app.ui.components.RooziCalendar
import com.roozi.app.ui.components.RooziCard
import com.roozi.app.ui.components.SectionHeader
import com.roozi.app.ui.components.accentTextShadow
import com.roozi.app.ui.components.DayLoad
import com.roozi.app.ui.theme.RooziTheme
import java.time.LocalDate

/**
 * The birthday notebook.
 *
 * Ordered by urgency: whoever is closest to their birthday sits at the top,
 * then the calendar, so the screen answers "who do I need to remember?" first.
 */
@Composable
fun BirthdayScreen(
    viewModel: BirthdayViewModel,
    onBack: () -> Unit,
    onAddPerson: () -> Unit,
    onOpenPerson: (BirthdayPerson) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current
    val people by viewModel.people.collectAsStateWithLifecycle()
    val selectedDate by viewModel.selectedDate.collectAsStateWithLifecycle()
    val today = remember { LocalDate.now() }

    // Days that have a birthday, for the calendar indicators.
    val loads: Map<LocalDate, DayLoad> = remember(people) {
        people.groupBy { LocalDate.now().plusDays(it.daysUntil.toLong()) }
            .mapValues { (_, list) -> DayLoad(total = list.size, done = 0) }
    }

    val onSelectedDay = remember(people, selectedDate) {
        val j = JalaliDate.fromLocalDate(selectedDate)
        people.filter { it.birthMonth == j.month && it.birthDay == j.day }
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(colors.tint(colors.pink), colors.background)
                )
            ),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 8.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item("header") {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = stringResource(R.string.cd_back),
                            tint = colors.textSecondary
                        )
                    }
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "🎂 " + stringResource(R.string.notebook_birthdays),
                        style = MaterialTheme.typography.headlineSmall,
                        color = colors.textPrimary
                    )
                }
                Text(
                    stringResource(R.string.birthdays_header_sub),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.textSecondary,
                    modifier = Modifier.padding(start = 8.dp, top = 2.dp)
                )
            }
        }

        if (people.isEmpty()) {
            item("empty") {
                EmptyState(
                    emoji = "🎂",
                    title = stringResource(R.string.empty_birthdays),
                    subtitle = stringResource(R.string.empty_birthdays_sub)
                )
            }
        } else {
            item("upcomingHeader") {
                SectionHeader(stringResource(R.string.upcoming_birthdays))
            }
            items(people, key = { it.id }) { person ->
                AnimatedVisibility(
                    visible = true,
                    enter = fadeIn(tween(220)) + slideInVertically { it / 8 }
                ) {
                    PersonCard(person = person, onClick = { onOpenPerson(person) })
                }
            }
        }

        item("calendarHeader") {
            Spacer(Modifier.height(4.dp))
            SectionHeader(stringResource(R.string.birthday_calendar))
        }

        item("calendar") {
            RooziCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(14.dp)) {
                RooziCalendar(
                    formatter = formatter,
                    selectedDate = selectedDate,
                    onSelectDate = viewModel::selectDate,
                    loads = loads,
                    today = today,
                    onVisibleMonthChange = {}
                )
            }
        }

        if (onSelectedDay.isEmpty()) {
            item("noneOnDay") {
                Text(
                    stringResource(R.string.no_birthday_on_day),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.textSecondary,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
        } else {
            items(onSelectedDay, key = { "day-${it.id}" }) { person ->
                PersonCard(person = person, onClick = { onOpenPerson(person) })
            }
        }
    }
}

/** One person: avatar, name, date and how far away the birthday is. */
@Composable
fun PersonCard(
    person: BirthdayPerson,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current

    // Today gets the full brand gradient so it is impossible to miss.
    val accent = when {
        person.isToday -> colors.coral
        person.isTomorrow -> colors.orange
        else -> colors.purple
    }

    RooziCard(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .clickable(onClick = onClick),
        contentPadding = PaddingValues(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(
                        if (person.isToday)
                            Brush.linearGradient(listOf(colors.coral, colors.purple))
                        else Brush.linearGradient(listOf(colors.tint(accent), colors.tint(accent)))
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(person.displayAvatar, style = MaterialTheme.typography.titleMedium)
            }

            Spacer(Modifier.width(12.dp))

            Column(Modifier.weight(1f)) {
                Text(
                    person.name,
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    formatter.jalaliDayMonth(person.birthMonth, person.birthDay),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.textSecondary
                )
                // Age is only shown when the birth year is known.
                person.turningAge?.let { age ->
                    Text(
                        stringResource(R.string.turns_age, formatter.digits(age)),
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary.copy(alpha = 0.8f)
                    )
                }
            }

            CountdownChip(person = person, accent = accent)
        }
    }
}

@Composable
private fun CountdownChip(person: BirthdayPerson, accent: Color) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current

    val label = when {
        person.isToday -> stringResource(R.string.birthday_today)
        person.isTomorrow -> stringResource(R.string.birthday_tomorrow)
        else -> stringResource(R.string.birthday_in_days, formatter.digits(person.daysUntil))
    }

    if (person.isToday) {
        Box(
            Modifier
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(colors.coral, colors.purple)))
                .padding(horizontal = 12.dp, vertical = 6.dp)
        ) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                color = Color.White
            )
        }
    } else {
        Box(
            Modifier
                .clip(CircleShape)
                .background(colors.tint(accent))
                .padding(horizontal = 12.dp, vertical = 6.dp)
        ) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                color = colors.onTint(accent),
                maxLines = 1
            )
        }
    }
}
