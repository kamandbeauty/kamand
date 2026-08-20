package com.studiojavid.memory.ui.diary

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material3.Icon
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
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.memory.R
import com.studiojavid.memory.data.local.Mood
import com.studiojavid.memory.data.repo.MemoryPage
import com.studiojavid.memory.ui.LocalDateFormatter
import com.studiojavid.memory.ui.MemoryViewModel
import com.studiojavid.memory.ui.components.EmptyState
import com.studiojavid.memory.ui.components.MemoryCard
import com.studiojavid.memory.ui.components.MemoryPageCard
import com.studiojavid.memory.ui.components.Pill
import com.studiojavid.memory.ui.components.SectionHeader
import com.studiojavid.memory.ui.components.accentTextShadow
import com.studiojavid.memory.ui.components.color
import com.studiojavid.memory.ui.components.emoji
import com.studiojavid.memory.ui.theme.MemoryTheme
import com.studiojavid.memory.ui.theme.timeOfDayGradient
import java.time.LocalDate
import java.time.LocalTime

/**
 * The diary tab.
 *
 * Today comes first as a single prominent card — written or not — because the
 * one thing a journal must make effortless is writing today's page. Everything
 * below it (this-day-in-past-years, then recent pages) is looking back.
 */
@Composable
fun DiaryScreen(
    viewModel: MemoryViewModel,
    userName: String,
    onOpenPage: (LocalDate) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    val formatter = LocalDateFormatter.current
    val diary by viewModel.diary.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val today by viewModel.today.collectAsStateWithLifecycle()
    val hour = remember { LocalTime.now().hour }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors.timeOfDayGradient(hour))),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item(key = "greeting") {
            Greeting(
                userName = userName,
                dateLabel = formatter.weekdayAndDate(today),
                streak = stats.streak,
                streakLabel = formatter.digits(stats.streak)
            )
        }

        item(key = "todayCard") {
            TodayPageCard(
                page = diary.page.takeIf { it?.date == today },
                onClick = { onOpenPage(today) }
            )
        }

        if (diary.onThisDay.isNotEmpty()) {
            item(key = "onThisDayHeader") {
                SectionHeader(title = "🕰️ " + stringResource(R.string.on_this_day))
            }
            item(key = "onThisDay") {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(diary.onThisDay, key = { it.id }) { page ->
                        LookBackCard(
                            page = page,
                            yearLabel = formatter.digits(
                                com.studiojavid.memory.core.date.JalaliDate
                                    .fromLocalDate(page.date).year
                            ),
                            onClick = { onOpenPage(page.date) }
                        )
                    }
                }
            }
        }

        item(key = "recentHeader") {
            SectionHeader(
                title = "📖 " + stringResource(R.string.recent_memories),
                trailing = {
                    if (stats.total > 0) {
                        Pill(
                            text = stringResource(
                                R.string.memory_count,
                                formatter.digits(stats.total)
                            ),
                            color = colors.purple
                        )
                    }
                }
            )
        }

        // Today already has its own card at the top; repeating it here would
        // make the list look like the page was saved twice.
        val recent = diary.recent.filter { it.date != today }
        if (recent.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    title = stringResource(R.string.no_memories_yet),
                    subtitle = stringResource(R.string.no_memories_hint)
                )
            }
        } else {
            items(recent, key = { it.id }) { page ->
                MemoryPageCard(
                    page = page,
                    dateLabel = formatter.weekdayAndDate(page.date),
                    photo = viewModel.photoFile(page.photo),
                    onClick = { onOpenPage(page.date) },
                    onToggleFavorite = { viewModel.toggleFavorite(page) },
                    modifier = Modifier.animateItem()
                )
            }
        }
    }
}

@Composable
private fun Greeting(
    userName: String,
    dateLabel: String,
    streak: Int,
    streakLabel: String
) {
    val colors = MemoryTheme.colors
    Column {
        Text(
            if (userName.isBlank()) stringResource(R.string.greeting_no_name)
            else stringResource(R.string.greeting_named, userName),
            style = MaterialTheme.typography.headlineSmall,
            color = colors.textPrimary
        )
        Spacer(Modifier.height(4.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                dateLabel,
                style = MaterialTheme.typography.bodyMedium,
                color = colors.textSecondary
            )
            if (streak > 0) {
                Pill(
                    text = stringResource(R.string.writing_streak, streakLabel),
                    color = colors.orange,
                    leading = "🔥"
                )
            }
        }
    }
}

/**
 * Today's page, or the invitation to write it.
 *
 * Deliberately not a [MemoryPageCard]: the empty state has to be as inviting
 * as the written one, and a shared card would have to grow a mode flag that
 * changes almost everything it draws.
 */
@Composable
private fun TodayPageCard(page: MemoryPage?, onClick: () -> Unit) {
    val colors = MemoryTheme.colors
    val accent = page?.mood?.takeIf { it != Mood.UNSET }?.color() ?: colors.purple

    MemoryCard(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .clickable(onClick = onClick),
        contentPadding = PaddingValues(18.dp)
    ) {
        Column(Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(listOf(accent, colors.purple))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (page?.mood != null && page.mood != Mood.UNSET) {
                        Text(page.mood.emoji, fontSize = 22.sp)
                    } else {
                        Icon(
                            Icons.Rounded.EditNote,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
                Spacer(Modifier.size(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(
                            if (page == null) R.string.today_page_empty_title
                            else R.string.today_page_title
                        ),
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.textPrimary
                    )
                    Text(
                        page?.title?.takeIf { it.isNotBlank() }
                            ?: page?.body?.takeIf { it.isNotBlank() }
                            ?: stringResource(R.string.today_page_empty_hint),
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

@Composable
private fun LookBackCard(page: MemoryPage, yearLabel: String, onClick: () -> Unit) {
    val colors = MemoryTheme.colors
    val accent = page.mood.takeIf { it != Mood.UNSET }?.color() ?: colors.turquoise

    MemoryCard(
        modifier = Modifier
            .size(width = 190.dp, height = 108.dp)
            .clip(RoundedCornerShape(18.dp))
            .clickable(onClick = onClick),
        contentPadding = PaddingValues(14.dp)
    ) {
        Column(Modifier.fillMaxSize()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    Modifier
                        .clip(CircleShape)
                        .background(accent)
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        yearLabel,
                        style = MaterialTheme.typography.labelSmall.copy(
                            shadow = accentTextShadow()
                        ),
                        color = Color.White
                    )
                }
                if (page.mood != Mood.UNSET) Text(page.mood.emoji, fontSize = 14.sp)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                page.title.takeIf { it.isNotBlank() } ?: page.body,
                style = MaterialTheme.typography.bodySmall,
                color = colors.textSecondary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
