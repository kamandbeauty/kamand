package com.studiojavid.diary.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.studiojavid.diary.R
import com.studiojavid.diary.core.date.DateFormatter
import com.studiojavid.diary.core.date.MonthPage
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.ui.theme.DiaryTheme
import kotlinx.coroutines.launch
import java.time.LocalDate

/** Task load per day used to draw the indicator dots. */
/** What the month grid needs to know about a day: mood, and whether it has a photo. */
data class DayMark(val mood: Mood, val hasPhoto: Boolean)

/**
 * Month calendar that renders a genuine Jalali month in Persian and a
 * Gregorian month in English. Swipeable, animated, RTL-correct.
 */
@Composable
fun DiaryCalendar(
    formatter: DateFormatter,
    selectedDate: LocalDate,
    onSelectDate: (LocalDate) -> Unit,
    marks: Map<LocalDate, DayMark>,
    onVisibleMonthChange: (MonthPage) -> Unit,
    modifier: Modifier = Modifier,
    today: LocalDate = LocalDate.now()
) {
    val persian = formatter.persian
    val colors = DiaryTheme.colors
    val scope = rememberCoroutineScope()

    val basePage = remember(persian) { MonthPage.of(persian, today) }
    val baseIndex = remember(basePage) { basePage.index }
    // A wide but finite range: ±60 years around today.
    val pageCount = 12 * 120 + 1
    val centerPage = pageCount / 2

    val pagerState = rememberPagerState(
        initialPage = centerPage + (MonthPage.of(persian, selectedDate).index - baseIndex),
        pageCount = { pageCount }
    )

    fun pageOf(index: Int): MonthPage = MonthPage.fromIndex(persian, baseIndex + (index - centerPage))

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { onVisibleMonthChange(pageOf(it)) }
    }

    // Keep the pager in sync when the selection jumps to another month (e.g. "Today").
    LaunchedEffect(selectedDate, persian) {
        val target = centerPage + (MonthPage.of(persian, selectedDate).index - baseIndex)
        if (target != pagerState.currentPage && target in 0 until pageCount) {
            pagerState.animateScrollToPage(target)
        }
    }

    val visibleMonth = pageOf(pagerState.currentPage)

    Column(modifier = modifier) {
        MonthHeader(
            title = formatter.monthTitle(visibleMonth),
            onPrevious = { scope.launch { pagerState.animateScrollToPage((pagerState.currentPage - 1).coerceAtLeast(0)) } },
            onNext = { scope.launch { pagerState.animateScrollToPage((pagerState.currentPage + 1).coerceAtMost(pageCount - 1)) } },
            onToday = { onSelectDate(today) },
            todayHighlighted = selectedDate == today
        )
        Spacer(Modifier.height(10.dp))
        WeekdayHeaderRow(formatter.weekdayHeaders(), if (persian) 6 else 0)
        Spacer(Modifier.height(4.dp))
        HorizontalPager(
            state = pagerState,
            pageSpacing = 8.dp,
            verticalAlignment = Alignment.Top
        ) { page ->
            MonthGrid(
                month = pageOf(page),
                formatter = formatter,
                selectedDate = selectedDate,
                today = today,
                marks = marks,
                onSelectDate = onSelectDate
            )
        }
    }
}

@Composable
private fun MonthHeader(
    title: String,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onToday: () -> Unit,
    todayHighlighted: Boolean
) {
    val colors = DiaryTheme.colors
    // A coloured band gives the calendar an identity instead of the flat
    // white sheet a default DatePicker has.
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Brush.linearGradient(listOf(colors.coral, colors.purple)))
            .padding(horizontal = 6.dp, vertical = 6.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onPrevious, modifier = Modifier.size(40.dp)) {
                    Icon(
                        Icons.AutoMirrored.Rounded.KeyboardArrowLeft,
                        contentDescription = stringResource(R.string.previous_month),
                        tint = Color.White
                    )
                }
                AnimatedContent(
                    targetState = title,
                    transitionSpec = {
                        (slideInHorizontally { it / 3 } + fadeIn(tween(180))) togetherWith
                            (slideOutHorizontally { -it / 3 } + fadeOut(tween(140)))
                    },
                    label = "monthTitle"
                ) { text ->
                    Text(
                        text,
                        style = MaterialTheme.typography.titleMedium.copy(shadow = accentTextShadow()),
                        color = Color.White,
                        modifier = Modifier.padding(horizontal = 4.dp)
                    )
                }
                IconButton(onClick = onNext, modifier = Modifier.size(40.dp)) {
                    Icon(
                        Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                        contentDescription = stringResource(R.string.next_month),
                        tint = Color.White
                    )
                }
            }
            // Translucent "today" chip so it reads on the gradient.
            Box(
                Modifier
                    .padding(end = 6.dp)
                    .clip(CircleShape)
                    .background(
                        if (todayHighlighted) Color.White.copy(alpha = 0.30f)
                        else Color.White.copy(alpha = 0.16f)
                    )
                    .clickable(onClick = onToday)
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Text(
                    stringResource(R.string.calendar_today),
                    style = MaterialTheme.typography.labelLarge.copy(shadow = accentTextShadow()),
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun WeekdayHeaderRow(labels: List<String>, weekendIndex: Int) {
    val colors = DiaryTheme.colors
    Row(Modifier.fillMaxWidth()) {
        labels.forEachIndexed { index, label ->
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                // The weekend column is warmer, like a paper wall calendar.
                color = if (index == weekendIndex) colors.coral else colors.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun MonthGrid(
    month: MonthPage,
    formatter: DateFormatter,
    selectedDate: LocalDate,
    today: LocalDate,
    marks: Map<LocalDate, DayMark>,
    onSelectDate: (LocalDate) -> Unit
) {
    val blanks = month.leadingBlanks
    val length = month.length
    val rows = ((blanks + length + 6) / 7)

    Column(Modifier.fillMaxWidth()) {
        for (row in 0 until rows) {
            Row(Modifier.fillMaxWidth()) {
                for (col in 0 until 7) {
                    val dayNumber = row * 7 + col - blanks + 1
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        if (dayNumber in 1..length) {
                            val date = month.dateOfDay(dayNumber)
                            DayCell(
                                label = formatter.digits(dayNumber),
                                date = date,
                                isToday = date == today,
                                isSelected = date == selectedDate,
                                mark = marks[date],
                                accessibilityLabel = formatter.fullDate(date),
                                onClick = { onSelectDate(date) }
                            )
                        } else {
                            Spacer(Modifier.size(44.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    label: String,
    date: LocalDate,
    isToday: Boolean,
    isSelected: Boolean,
    mark: DayMark?,
    accessibilityLabel: String,
    onClick: () -> Unit
) {
    val colors = DiaryTheme.colors
    val written = mark != null

    // A written day is tinted with its own mood, so a month of the calendar
    // reads as a mood map rather than a grid of identical dots.
    val moodAccent = mark?.mood?.takeIf { it != Mood.UNSET }?.color() ?: colors.purple
    val writtenTint = if (written) colors.tint(moodAccent) else Color.Transparent
    val background by animateColorAsState(
        when {
            isSelected -> colors.coral
            isToday -> colors.tint(colors.coral)
            else -> writtenTint
        },
        tween(220),
        label = "dayBg"
    )
    val textColor by animateColorAsState(
        when {
            isSelected -> Color.White
            isToday -> colors.onTint(colors.coral)
            written -> colors.onTint(moodAccent)
            else -> colors.textPrimary
        },
        tween(220),
        label = "dayFg"
    )
    val scale by animateFloatAsState(
        if (isSelected) 1f else 0.94f,
        spring(dampingRatio = 0.5f, stiffness = 420f),
        label = "dayScale"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .padding(vertical = 2.dp)
            .clearAndSetSemantics { contentDescription = accessibilityLabel }
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .scale(scale)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .then(
                        if (isSelected) Modifier.background(
                            Brush.linearGradient(listOf(colors.coral, colors.purple))
                        ) else Modifier.background(background)
                    )
                    .then(
                        if (isToday && !isSelected)
                            Modifier.border(1.5.dp, colors.coral.copy(alpha = 0.55f), CircleShape)
                        else Modifier
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    label,
                    style = if (isSelected)
                        MaterialTheme.typography.labelLarge.copy(shadow = accentTextShadow())
                    else MaterialTheme.typography.labelLarge,
                    color = textColor
                )
            }
        }
        DayIndicator(mark = mark, selected = isSelected)
    }
}

@Composable
private fun DayIndicator(mark: DayMark?, selected: Boolean) {
    val colors = DiaryTheme.colors
    val accent = mark?.mood?.takeIf { it != Mood.UNSET }?.color() ?: colors.purple
    Box(Modifier.height(8.dp), contentAlignment = Alignment.Center) {
        if (mark != null) {
            val color = if (selected) Color.White else accent
            Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                Box(Modifier.size(4.dp).background(color, CircleShape))
                // A second dot marks the days that also carry a photo.
                if (mark.hasPhoto) Box(Modifier.size(4.dp).background(color, CircleShape))
            }
        }
    }
}

/** Compact strip of day-cards used for quick date picking inside the add sheet. */
@Composable
fun DayCountBadge(count: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(
                Brush.linearGradient(
                    listOf(DiaryTheme.colors.coral, DiaryTheme.colors.purple)
                )
            )
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(
            count,
            style = MaterialTheme.typography.labelSmall.copy(shadow = accentTextShadow()),
            color = Color.White
        )
    }
}
