package com.roozi.app.ui.today

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.roozi.app.R
import com.roozi.app.data.repo.Task
import com.roozi.app.ui.LocalDateFormatter
import com.roozi.app.ui.TasksViewModel
import com.roozi.app.ui.TodayUiState
import com.roozi.app.ui.components.CelebrationOverlay
import com.roozi.app.ui.components.EmptyState
import com.roozi.app.ui.components.ProgressRing
import com.roozi.app.ui.components.RooziCard
import com.roozi.app.ui.components.SectionHeader
import com.roozi.app.ui.components.SwipeableTaskCard
import com.roozi.app.ui.displayName
import com.roozi.app.ui.theme.RooziTheme
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.LocalTime

@Composable
fun TodayScreen(
    viewModel: TasksViewModel,
    userName: String,
    onOpenTask: (Task) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val state by viewModel.todayState.collectAsStateWithLifecycle()
    val celebrate by viewModel.celebrate.collectAsStateWithLifecycle()
    val formatter = LocalDateFormatter.current
    val colors = RooziTheme.colors
    val today by viewModel.today.collectAsStateWithLifecycle()

    LaunchedEffect(state.total, state.done) { viewModel.onProgressChanged(state) }
    LaunchedEffect(celebrate) {
        if (celebrate) {
            delay(2600)
            viewModel.dismissCelebration()
        }
    }

    val pending = state.tasks.filter { !it.isCompleted }
    val done = state.tasks.filter { it.isCompleted }

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
        item(key = "header") {
            GreetingHeader(userName = userName, state = state, today = today)
        }

        item(key = "progress") {
            ProgressCard(state = state)
        }

        item(key = "celebration") {
            CelebrationOverlay(
                visible = celebrate,
                title = stringResource(R.string.celebration_title),
                subtitle = stringResource(R.string.celebration_subtitle)
            )
        }

        if (state.tasks.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    emoji = "🌴",
                    title = stringResource(R.string.empty_today),
                    subtitle = stringResource(R.string.empty_today_sub)
                )
            }
        } else {
            item(key = "sectionPending") {
                Spacer(Modifier.height(4.dp))
                SectionHeader(
                    title = stringResource(R.string.today_tasks),
                    trailing = {
                        Text(
                            formatter.digits(pending.size),
                            style = MaterialTheme.typography.labelLarge,
                            color = colors.textSecondary
                        )
                    }
                )
            }

            items(pending, key = { it.id }) { task ->
                TaskRow(task = task, viewModel = viewModel, onOpenTask = onOpenTask)
            }

            if (done.isNotEmpty()) {
                item(key = "sectionDone") {
                    Spacer(Modifier.height(8.dp))
                    SectionHeader(
                        title = stringResource(R.string.completed_tasks),
                        trailing = {
                            Text(
                                formatter.digits(done.size),
                                style = MaterialTheme.typography.labelLarge,
                                color = colors.textSecondary
                            )
                        }
                    )
                }
                items(done, key = { it.id }) { task ->
                    TaskRow(task = task, viewModel = viewModel, onOpenTask = onOpenTask)
                }
            }
        }
    }
}

@Composable
private fun TaskRow(task: Task, viewModel: TasksViewModel, onOpenTask: (Task) -> Unit) {
    val formatter = LocalDateFormatter.current
    val subtitle = buildString {
        append(task.dueDate?.let { formatter.relativeDate(it) } ?: stringResource(R.string.no_date))
        task.dueTimeMinutes?.let {
            append(" · ")
            append(formatter.time(it))
        }
    }
    val priorityLabel = stringResource(
        when (task.priority) {
            com.roozi.app.data.local.Priority.LOW -> R.string.priority_low
            com.roozi.app.data.local.Priority.MEDIUM -> R.string.priority_medium
            com.roozi.app.data.local.Priority.HIGH -> R.string.priority_high
        }
    )
    AnimatedVisibility(
        visible = true,
        enter = fadeIn(tween(220)) + scaleIn(initialScale = 0.94f) + slideInVertically { it / 6 },
        exit = fadeOut(tween(160)) + shrinkVertically()
    ) {
        SwipeableTaskCard(
            task = task,
            subtitle = subtitle,
            categoryLabel = task.category?.displayName(),
            priorityLabel = priorityLabel,
            onToggle = { viewModel.toggleTask(task) },
            onClick = { onOpenTask(task) },
            onDelete = { viewModel.deleteTask(task) }
        )
    }
}

@Composable
private fun GreetingHeader(userName: String, state: TodayUiState, today: LocalDate) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current
    val hour = remberHour()

    val greetingRes = when (hour) {
        in 5..11 -> R.string.greeting_morning
        in 12..15 -> R.string.greeting_noon
        in 16..19 -> R.string.greeting_evening
        else -> R.string.greeting_night
    }
    val emojiRes = when (hour) {
        in 5..11 -> R.string.greeting_morning_emoji
        in 12..15 -> R.string.greeting_noon_emoji
        in 16..19 -> R.string.greeting_evening_emoji
        else -> R.string.greeting_night_emoji
    }
    val greeting = stringResource(greetingRes)
    val emoji = stringResource(emojiRes)
    val title = if (userName.isBlank()) "$greeting ${stringResource(R.string.greeting_no_name)}"
    else "$greeting $userName $emoji"

    Column(Modifier.fillMaxWidth()) {
        Text(title, style = MaterialTheme.typography.headlineSmall, color = colors.textPrimary)
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (state.total == 0) stringResource(R.string.home_no_tasks)
            else stringResource(R.string.home_tasks_count, formatter.digits(state.total)),
            style = MaterialTheme.typography.bodyMedium,
            color = colors.textSecondary
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = formatter.weekdayAndDate(today),
            style = MaterialTheme.typography.labelMedium,
            color = colors.textSecondary.copy(alpha = 0.8f)
        )
    }
}

@Composable
private fun remberHour(): Int = androidx.compose.runtime.remember { LocalTime.now().hour }

@Composable
private fun ProgressCard(state: TodayUiState) {
    val colors = RooziTheme.colors
    val formatter = LocalDateFormatter.current
    val hour = remberHour()

    val message = when {
        state.total == 0 && hour >= 20 -> stringResource(R.string.smart_night)
        state.total == 0 -> stringResource(R.string.smart_start)
        state.allDone -> stringResource(R.string.smart_done)
        state.progress >= 0.6f -> stringResource(R.string.smart_almost)
        state.done > 0 -> stringResource(R.string.smart_going_well)
        hour >= 20 -> stringResource(R.string.smart_night)
        else -> stringResource(R.string.smart_start)
    }

    RooziCard(modifier = Modifier.fillMaxWidth(), contentPadding = PaddingValues(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ProgressRing(
                progress = state.progress,
                centerTop = formatter.percent(state.percent),
                centerBottom = stringResource(
                    R.string.progress_of,
                    formatter.digits(state.done),
                    formatter.digits(state.total)
                ),
                contentDescription = stringResource(R.string.cd_progress_ring)
            )
            Spacer(Modifier.width(18.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.progress_title),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.textSecondary
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    message,
                    style = MaterialTheme.typography.titleMedium,
                    color = colors.textPrimary
                )
            }
        }
    }
}
