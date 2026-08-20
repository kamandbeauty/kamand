package com.studiojavid.memory.ui.today

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import com.studiojavid.memory.ui.components.accentTextShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.memory.R
import com.studiojavid.memory.data.local.Priority
import com.studiojavid.memory.data.repo.Task
import com.studiojavid.memory.ui.LocalDateFormatter
import com.studiojavid.memory.ui.TasksViewModel
import com.studiojavid.memory.ui.TodayUiState
import com.studiojavid.memory.ui.components.CelebrationOverlay
import com.studiojavid.memory.ui.components.EmptyState
import com.studiojavid.memory.ui.components.Pill
import com.studiojavid.memory.ui.components.ProgressRing
import com.studiojavid.memory.ui.components.MemoryCard
import com.studiojavid.memory.ui.components.SectionHeader
import com.studiojavid.memory.ui.components.SwipeableTaskCard
import com.studiojavid.memory.ui.rememberReduceMotion
import com.studiojavid.memory.ui.displayName
import com.studiojavid.memory.ui.theme.MemoryTheme
import com.studiojavid.memory.ui.theme.timeOfDayGradient
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalTime
import kotlin.math.roundToInt

/**
 * The Daily Planner.
 *
 * Section order is intentional: greeting → progress → quick add → the timed
 * plan → anytime tasks → undated backlog → completed. Nothing below the fold
 * competes with "what should I do next?".
 */
@Composable
fun TodayScreen(
    viewModel: TasksViewModel,
    userName: String,
    onOpenTask: (Task) -> Unit,
    onTaskActions: (Task) -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val state by viewModel.todayState.collectAsStateWithLifecycle()
    val celebrate by viewModel.celebrate.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val undated by viewModel.undated.collectAsStateWithLifecycle()
    val today by viewModel.today.collectAsStateWithLifecycle()
    val formatter = LocalDateFormatter.current
    val colors = MemoryTheme.colors
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Respect the system "remove animations" setting (§24/§25).
    val reduceMotion = rememberReduceMotion()
    val animator = rememberCompletionAnimator(scope, reduceMotion)

    LaunchedEffect(state.total, state.done) { viewModel.onProgressChanged(state) }
    LaunchedEffect(celebrate) {
        if (celebrate) {
            delay(2600)
            viewModel.dismissCelebration()
        }
    }

    // A task being struck through stays in its original section until the pen
    // finishes; otherwise its list key changes, the row is recreated and the
    // animation is destroyed mid-flight.
    val holding: (Task) -> Boolean = { animator.holdsPosition(it.id) }

    val timed = state.tasks.filter { (!it.isCompleted || holding(it)) && it.hasTime }
    val anytime = state.tasks.filter { (!it.isCompleted || holding(it)) && !it.hasTime }
    val doneTasks = state.completedTasks.filterNot(holding)
    val pendingUndated = undated.filter { !it.isCompleted || holding(it) }

    // Drag & drop applies to the "anytime" group, where manual order is meaningful.
    val reorder = rememberReorderState(
        items = anytime,
        onCommit = { ids -> viewModel.persistOrder(ids) }
    )

    LazyColumn(
        state = listState,
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors.timeOfDayGradient(rememberHour()))),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item(key = "header") {
            GreetingHeader(userName = userName, state = state, today = today, streak = stats.streak)
        }

        item(key = "progress") { ProgressCard(state = state) }

        item(key = "celebration") {
            CelebrationOverlay(
                visible = celebrate,
                title = stringResource(R.string.celebration_title),
                subtitle = stringResource(R.string.celebration_subtitle)
            )
        }

        item(key = "quickadd") {
            QuickAddBar(
                persian = formatter.persian,
                onAdd = { title -> viewModel.quickAdd(title, today) }
            )
        }

        if (state.tasks.isEmpty() && pendingUndated.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    title = stringResource(R.string.empty_today),
                    subtitle = stringResource(R.string.empty_today_sub)
                )
            }
        }

        // ---- The timed plan -------------------------------------------------
        if (timed.isNotEmpty()) {
            item(key = "timedHeader") {
                Spacer(Modifier.height(2.dp))
                SectionHeader(
                    title = stringResource(R.string.section_plan_today),
                    trailing = { CountLabel(timed.size) }
                )
            }
            items(timed, key = { "t${it.id}" }) { task ->
                PlannerRow(
                    task = task,
                    viewModel = viewModel,
                    onOpenTask = onOpenTask,
                    onTaskActions = onTaskActions,
                    animator = animator,
                    modifier = Modifier.animateItem()
                )
            }
        }

        // ---- Anytime today (no clock time) — reorderable ---------------------
        if (anytime.isNotEmpty()) {
            item(key = "anytimeHeader") {
                Spacer(Modifier.height(2.dp))
                Column {
                    SectionHeader(
                        title = stringResource(R.string.section_anytime),
                        trailing = { CountLabel(anytime.size) }
                    )
                    if (anytime.size > 1) {
                        Text(
                            stringResource(R.string.reorder_hint),
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.textSecondary.copy(alpha = 0.75f),
                            modifier = Modifier.padding(top = 2.dp)
                        )
                    }
                }
            }
            items(reorder.items, key = { "a${it.id}" }) { task ->
                val isDragging = reorder.draggingId == task.id
                PlannerRow(
                    task = task,
                    viewModel = viewModel,
                    onOpenTask = onOpenTask,
                    onTaskActions = onTaskActions,
                    animator = animator,
                    modifier = Modifier
                        .zIndex(if (isDragging) 1f else 0f)
                        .graphicsLayer {
                            translationY = if (isDragging) reorder.dragOffset else 0f
                            scaleX = if (isDragging) 1.03f else 1f
                            scaleY = if (isDragging) 1.03f else 1f
                        }
                        .then(if (isDragging) Modifier else Modifier.animateItem())
                        .pointerInput(task.id, reorder.items.size) {
                            detectDragGesturesAfterLongPress(
                                onDragStart = {
                                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                    reorder.onDragStart(task.id)
                                },
                                onDrag = { change, amount ->
                                    change.consume()
                                    reorder.onDrag(amount.y, ROW_HEIGHT_PX)
                                },
                                onDragEnd = { reorder.onDragEnd() },
                                onDragCancel = { reorder.onDragEnd() }
                            )
                        }
                )
            }
        }

        // ---- Undated backlog -------------------------------------------------
        if (pendingUndated.isNotEmpty()) {
            item(key = "undatedHeader") {
                Spacer(Modifier.height(2.dp))
                Column {
                    SectionHeader(
                        title = stringResource(R.string.section_no_date),
                        trailing = { CountLabel(pendingUndated.size) }
                    )
                    Text(
                        stringResource(R.string.section_no_date_sub),
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary.copy(alpha = 0.75f),
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            }
            items(pendingUndated, key = { "u${it.id}" }) { task ->
                PlannerRow(
                    task = task,
                    viewModel = viewModel,
                    onOpenTask = onOpenTask,
                    onTaskActions = onTaskActions,
                    animator = animator,
                    modifier = Modifier.animateItem()
                )
            }
        }

        // ---- Completed --------------------------------------------------------
        if (doneTasks.isNotEmpty()) {
            item(key = "doneHeader") {
                Spacer(Modifier.height(2.dp))
                SectionHeader(
                    title = stringResource(R.string.completed_tasks),
                    trailing = { CountLabel(doneTasks.size) }
                )
            }
            items(doneTasks, key = { "d${it.id}" }) { task ->
                PlannerRow(
                    task = task,
                    viewModel = viewModel,
                    onOpenTask = onOpenTask,
                    onTaskActions = onTaskActions,
                    animator = animator,
                    modifier = Modifier.animateItem()
                )
            }
        }
    }
}

private const val ROW_HEIGHT_PX = 210f

@Composable
private fun CountLabel(count: Int) {
    val formatter = LocalDateFormatter.current
    Text(
        formatter.digits(count),
        style = MaterialTheme.typography.labelLarge,
        color = MemoryTheme.colors.textSecondary
    )
}

@Composable
private fun PlannerRow(
    task: Task,
    viewModel: TasksViewModel,
    onOpenTask: (Task) -> Unit,
    onTaskActions: (Task) -> Unit,
    animator: CompletionAnimator,
    modifier: Modifier = Modifier
) {
    val formatter = LocalDateFormatter.current
    val haptics = LocalHapticFeedback.current

    // Undated tasks must never show a fake date, and untimed ones never a fake clock.
    val subtitle = buildString {
        val date = task.dueDate
        if (date == null) {
            append(stringResource(R.string.section_no_date))
        } else {
            append(formatter.relativeDate(date))
            task.dueTimeMinutes?.let { append(" · "); append(formatter.time(it)) }
        }
    }

    // Animate only on a real incomplete → complete transition.
    val animateCompletion = animator.isAnimating(task.id)
    val onToggle = {
        if (task.isCompleted) {
            animator.onUncompleted(task.id)
            viewModel.toggleTask(task)
        } else {
            animator.onCompleted(task.id)
            viewModel.toggleTask(task)
        }
    }

    val priorityLabel = stringResource(
        when (task.priority) {
            Priority.LOW -> R.string.priority_low
            Priority.MEDIUM -> R.string.priority_medium
            Priority.HIGH -> R.string.priority_high
        }
    )

    SwipeableTaskCard(
        task = task,
        subtitle = subtitle,
        categoryLabel = task.category?.displayName(),
        priorityLabel = priorityLabel,
        onToggle = {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            onToggle()
        },
        onClick = { onOpenTask(task) },
        onLongClick = { onTaskActions(task) },
        onDelete = { viewModel.deleteTask(task) },
        animateCompletion = animateCompletion,
        modifier = modifier
    )
}

@Composable
private fun rememberHour(): Int = remember { LocalTime.now().hour }

@Composable
private fun GreetingHeader(
    userName: String,
    state: TodayUiState,
    today: LocalDate,
    streak: Int
) {
    val colors = MemoryTheme.colors
    val formatter = LocalDateFormatter.current
    val hour = rememberHour()

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
        // Progress at a glance: what is done and what is still waiting.
        Text(
            text = when {
                state.total == 0 -> stringResource(R.string.home_no_tasks)
                state.allDone -> stringResource(
                    R.string.home_all_done,
                    formatter.digits(state.total)
                )
                // One sentence for every in-progress state, including "none done
                // yet". A separate phrasing for zero made the line change shape
                // the moment the first task was ticked.
                else -> stringResource(
                    R.string.home_done_and_left,
                    formatter.digits(state.done),
                    formatter.digits(state.remaining)
                )
            },
            style = MaterialTheme.typography.bodyMedium,
            color = colors.textSecondary
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = formatter.weekdayAndDate(today),
                style = MaterialTheme.typography.labelMedium,
                color = colors.textSecondary.copy(alpha = 0.8f)
            )
            if (streak > 0) {
                Spacer(Modifier.width(8.dp))
                Pill(
                    text = stringResource(R.string.streak_value, formatter.digits(streak)),
                    color = colors.orange
                )
            }
        }
    }
}

@Composable
private fun ProgressCard(state: TodayUiState) {
    val colors = MemoryTheme.colors
    val formatter = LocalDateFormatter.current
    val hour = rememberHour()

    // Message reacts to the shape of the day, not just to a percentage.
    val message = when {
        state.total == 0 && hour >= 20 -> stringResource(R.string.smart_night)
        state.total == 0 -> stringResource(R.string.smart_start)
        state.allDone -> stringResource(R.string.smart_done)
        state.remaining == 1 -> stringResource(R.string.smart_last_one)
        state.progress >= 0.6f -> stringResource(R.string.smart_almost)
        state.progress >= 0.5f -> stringResource(R.string.smart_half)
        state.done > 0 -> stringResource(R.string.smart_going_well)
        hour >= 20 -> stringResource(R.string.smart_night)
        else -> stringResource(R.string.smart_start)
    }

    // Hero card: the one place a gradient is used on Today, so it stays special.
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .background(
                Brush.linearGradient(listOf(colors.coral, colors.purple))
            )
            .padding(18.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ProgressRing(
                progress = state.progress,
                centerTop = formatter.percent(state.percent),
                centerBottom = stringResource(
                    R.string.progress_of,
                    formatter.digits(state.done),
                    formatter.digits(state.total)
                ),
                contentDescription = stringResource(R.string.cd_progress_ring),
                onGradient = true
            )
            Spacer(Modifier.width(18.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.progress_title),
                    style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                    color = Color.White.copy(alpha = 0.9f)
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    message,
                    style = MaterialTheme.typography.titleMedium.copy(shadow = accentTextShadow()),
                    color = Color.White
                )
                if (state.total > 0) {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        stringResource(
                            R.string.hero_done_of,
                            formatter.digits(state.done),
                            formatter.digits(state.total)
                        ),
                        style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                        color = Color.White.copy(alpha = 0.85f)
                    )
                }
            }
        }
    }
}
