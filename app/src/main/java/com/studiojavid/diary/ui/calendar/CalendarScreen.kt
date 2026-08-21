package com.studiojavid.diary.ui.calendar

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.diary.R
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.ui.LocalDateFormatter
import com.studiojavid.diary.ui.DiaryViewModel
import com.studiojavid.diary.ui.components.DiaryCalendar
import com.studiojavid.diary.ui.components.DiaryCard
import com.studiojavid.diary.ui.components.DiaryPageCard
import com.studiojavid.diary.ui.components.Pill
import com.studiojavid.diary.ui.components.SectionHeader
import com.studiojavid.diary.ui.components.emoji
import com.studiojavid.diary.ui.components.label
import com.studiojavid.diary.ui.theme.DiaryTheme
import java.time.LocalDate

/**
 * Calendar tab: a Jalali month whose days are tinted by the mood written on
 * them, plus the page of whichever day is selected.
 */
@Composable
fun CalendarScreen(
    viewModel: DiaryViewModel,
    onOpenPage: (LocalDate) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val formatter = LocalDateFormatter.current
    val colors = DiaryTheme.colors
    val selectedDate by viewModel.selectedDate.collectAsStateWithLifecycle()
    val today by viewModel.today.collectAsStateWithLifecycle()
    val marks by viewModel.dayMarks.collectAsStateWithLifecycle()
    val diary by viewModel.diary.collectAsStateWithLifecycle()

    // The flow is keyed on the selected date, but a frame can arrive while the
    // previous day's page is still in state; comparing dates avoids showing
    // yesterday's text under today's header for that one frame.
    val page = diary.page?.takeIf { it.date == selectedDate }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(listOf(colors.gradientStart, colors.background))
            ),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item(key = "calendar") {
            DiaryCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(14.dp)) {
                DiaryCalendar(
                    formatter = formatter,
                    selectedDate = selectedDate,
                    onSelectDate = viewModel::selectDate,
                    marks = marks,
                    today = today,
                    onVisibleMonthChange = { monthPage ->
                        viewModel.setVisibleMonth(monthPage.firstDay, monthPage.lastDay)
                    }
                )
            }
        }

        item(key = "header") {
            Spacer(Modifier.height(2.dp))
            AnimatedContent(
                targetState = selectedDate,
                transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) },
                label = "dayHeader"
            ) { date ->
                SectionHeader(
                    title = formatter.weekdayAndDate(date),
                    trailing = {
                        val mood = page?.mood
                        if (mood != null && mood != Mood.UNSET) {
                            Pill(text = mood.label(), color = colors.purple, leading = mood.emoji)
                        }
                    }
                )
            }
        }

        item(key = "page") {
            if (page != null) {
                DiaryPageCard(
                    page = page,
                    dateLabel = formatter.weekdayAndDate(page.date),
                    photo = viewModel.photoFile(page.photo),
                    onClick = { onOpenPage(page.date) },
                    onToggleFavorite = { viewModel.toggleFavorite(page) }
                )
            } else {
                BlankDayCard(
                    future = selectedDate.isAfter(today),
                    onWrite = { onOpenPage(selectedDate) }
                )
            }
        }
    }
}

/**
 * A day with no page.
 *
 * A future day cannot be written yet — a diary records what happened — so the
 * card explains that instead of offering a button that would refuse to work.
 */
@Composable
private fun BlankDayCard(future: Boolean, onWrite: () -> Unit) {
    val colors = DiaryTheme.colors
    DiaryCard(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .then(if (future) Modifier else Modifier.clickable(onClick = onWrite)),
        contentPadding = PaddingValues(18.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Rounded.EditNote,
                contentDescription = null,
                tint = if (future) colors.textSecondary else colors.purple,
                modifier = Modifier.size(26.dp)
            )
            Spacer(Modifier.size(12.dp))
            Column {
                Text(
                    stringResource(
                        if (future) R.string.future_day_title else R.string.blank_day_title
                    ),
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.textPrimary
                )
                Text(
                    stringResource(
                        if (future) R.string.future_day_hint else R.string.blank_day_hint
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.textSecondary
                )
            }
        }
    }
}
