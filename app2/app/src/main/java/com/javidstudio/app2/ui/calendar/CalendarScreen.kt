package com.javidstudio.app2.ui.calendar

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.javidstudio.app2.R
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.repo.Task
import com.javidstudio.app2.ui.LocalDateFormatter
import com.javidstudio.app2.ui.TasksViewModel
import com.javidstudio.app2.ui.components.EmptyState
import com.javidstudio.app2.ui.components.Pill
import com.javidstudio.app2.ui.components.App2Calendar
import com.javidstudio.app2.ui.components.App2Card
import com.javidstudio.app2.ui.components.SectionHeader
import com.javidstudio.app2.ui.components.SwipeableTaskCard
import com.javidstudio.app2.ui.displayName
import com.javidstudio.app2.ui.theme.App2Theme

@Composable
fun CalendarScreen(
    viewModel: TasksViewModel,
    onOpenTask: (Task) -> Unit,
    onTaskActions: (Task) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val formatter = LocalDateFormatter.current
    val colors = App2Theme.colors
    val selectedDate by viewModel.selectedDate.collectAsStateWithLifecycle()
    val today by viewModel.today.collectAsStateWithLifecycle()
    val loads by viewModel.dayLoads.collectAsStateWithLifecycle()
    val tasks by viewModel.selectedDayTasks.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(colors.gradientStart, colors.background))),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item(key = "calendar") {
            App2Card(Modifier.fillMaxWidth(), contentPadding = PaddingValues(14.dp)) {
                App2Calendar(
                    formatter = formatter,
                    selectedDate = selectedDate,
                    onSelectDate = viewModel::selectDate,
                    loads = loads,
                    today = today,
                    onVisibleMonthChange = { page ->
                        viewModel.setVisibleMonth(page.firstDay, page.lastDay)
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
                        // Count chip picks up the day's state: green when the
                        // day is clear, warm while work is still pending.
                        val allDone = tasks.isNotEmpty() && tasks.all { it.isCompleted }
                        val chip = when {
                            tasks.isEmpty() -> colors.textSecondary
                            allDone -> colors.success
                            else -> colors.orange
                        }
                        Pill(
                            text = stringResource(
                                R.string.day_task_count,
                                formatter.digits(tasks.size)
                            ),
                            color = chip
                        )
                    }
                )
            }
        }

        if (tasks.isEmpty()) {
            item(key = "empty") {
                // A future date reads as "nothing planned yet", a past/today one
                // as "nothing was scheduled" — same screen, honest wording.
                val future = selectedDate.isAfter(today)
                EmptyState(
                    title = stringResource(
                        if (future) R.string.empty_future else R.string.no_tasks_this_day
                    )
                )
            }
        } else {
            items(tasks, key = { it.id }) { task ->
                val subtitle = buildString {
                    append(formatter.relativeDate(task.dueDate ?: selectedDate))
                    task.dueTimeMinutes?.let { append(" · "); append(formatter.time(it)) }
                }
                SwipeableTaskCard(
                    task = task,
                    subtitle = subtitle,
                    categoryLabel = task.category?.displayName(),
                    priorityLabel = stringResource(
                        when (task.priority) {
                            Priority.LOW -> R.string.priority_low
                            Priority.MEDIUM -> R.string.priority_medium
                            Priority.HIGH -> R.string.priority_high
                        }
                    ),
                    onToggle = { viewModel.toggleTask(task) },
                    onClick = { onOpenTask(task) },
                    onLongClick = { onTaskActions(task) },
                    onDelete = { viewModel.deleteTask(task) },
                    modifier = Modifier.animateItem()
                )
            }
        }
    }
}
