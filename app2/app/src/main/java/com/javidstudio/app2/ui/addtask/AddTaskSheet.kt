package com.javidstudio.app2.ui.addtask

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.R
import com.javidstudio.app2.core.date.DateFormatter
import com.javidstudio.app2.core.recurrence.RecurrenceRule
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.repo.Category
import com.javidstudio.app2.data.repo.Task
import com.javidstudio.app2.ui.components.ChipRow
import com.javidstudio.app2.ui.components.SelectableChip
import com.javidstudio.app2.ui.displayName
import com.javidstudio.app2.ui.theme.App2Theme
import java.time.LocalDate
import java.time.LocalTime

/** Result emitted when the user saves the sheet. */
data class TaskDraft(
    val id: Long,
    val title: String,
    val description: String,
    val categoryId: Long?,
    val dueDate: LocalDate?,
    val dueTimeMinutes: Int?,
    val priority: Priority,
    val reminderEnabled: Boolean,
    val repeat: RecurrenceRule
)

/**
 * The add / edit sheet.
 *
 * Fast path: type a title, hit save. Everything else lives behind a single
 * "more options" expander so a simple task never costs more than two taps.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTaskSheet(
    sheetState: SheetState,
    formatter: DateFormatter,
    categories: List<Category>,
    editing: Task?,
    defaultDate: LocalDate,
    onDismiss: () -> Unit,
    onSave: (TaskDraft) -> Unit,
    onReminderEnabled: () -> Unit = {}
) {
    val colors = App2Theme.colors

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.surface,
        dragHandle = { SheetHandle() },
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        AddTaskContent(
            formatter = formatter,
            categories = categories,
            editing = editing,
            defaultDate = defaultDate,
            onSave = onSave,
            onReminderEnabled = onReminderEnabled
        )
    }
}

@Composable
private fun SheetHandle() {
    Box(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(width = 42.dp, height = 5.dp)
                .background(App2Theme.colors.textSecondary.copy(alpha = 0.3f), RoundedCornerShape(3.dp))
        )
    }
}

@Composable
private fun AddTaskContent(
    formatter: DateFormatter,
    categories: List<Category>,
    editing: Task?,
    defaultDate: LocalDate,
    onSave: (TaskDraft) -> Unit,
    onReminderEnabled: () -> Unit
) {
    val colors = App2Theme.colors
    val keyboard = LocalSoftwareKeyboardController.current

    var title by rememberSaveable(editing?.id) { mutableStateOf(editing?.title ?: "") }
    var description by rememberSaveable(editing?.id) { mutableStateOf(editing?.description ?: "") }
    var categoryId by rememberSaveable(editing?.id) { mutableStateOf(editing?.category?.id) }
    // A brand-new task starts with NO date: the user opts in, never out.
    var dueDate by remember(editing?.id) { mutableStateOf(editing?.dueDate) }
    var dueTime by rememberSaveable(editing?.id) { mutableStateOf(editing?.dueTimeMinutes) }
    var priority by rememberSaveable(editing?.id) { mutableStateOf(editing?.priority ?: Priority.MEDIUM) }
    var reminder by rememberSaveable(editing?.id) { mutableStateOf(editing?.reminderEnabled ?: false) }
    // RecurrenceRule is not Parcelable; persist its compact string form instead.
    var repeatRaw by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.repeat?.serialize() ?: "")
    }
    val repeat = RecurrenceRule.parse(repeatRaw)

    var expanded by rememberSaveable { mutableStateOf(editing != null) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }
    var showTimePicker by rememberSaveable { mutableStateOf(false) }

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        if (editing == null) {
            kotlinx.coroutines.delay(120)
            runCatching { focusRequester.requestFocus() }
        }
    }

    val canSave = title.isNotBlank()

    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 20.dp)
            .animateContentSize(spring(dampingRatio = 0.85f))
    ) {
        Text(
            stringResource(if (editing == null) R.string.add_task else R.string.edit_task),
            style = MaterialTheme.typography.titleMedium,
            color = colors.textPrimary
        )
        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            placeholder = { Text(stringResource(R.string.task_title_hint)) },
            label = { Text(stringResource(R.string.task_title)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = {
                if (canSave) {
                    keyboard?.hide()
                    onSave(
                        TaskDraft(
                            editing?.id ?: 0L, title, description, categoryId,
                            dueDate, dueTime, priority, reminder, repeat
                        )
                    )
                }
            }),
            colors = fieldColors()
        )

        Spacer(Modifier.height(10.dp))

        // §14: one-tap scheduling. Today / Tomorrow cover the vast majority of
        // cases; the calendar chip below stays for everything else.
        val today = remember { LocalDate.now() }
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SelectableChip(
                text = stringResource(R.string.task_today),
                selected = dueDate == today,
                accent = colors.coral,
                onClick = { dueDate = if (dueDate == today) null else today }
            )
            SelectableChip(
                text = stringResource(R.string.task_tomorrow),
                selected = dueDate == today.plusDays(1),
                accent = colors.orange,
                onClick = {
                    val tomorrow = today.plusDays(1)
                    dueDate = if (dueDate == tomorrow) null else tomorrow
                }
            )
            SelectableChip(
                text = stringResource(R.string.pick_a_day),
                selected = showDatePicker,
                accent = colors.purple,
                onClick = { showDatePicker = !showDatePicker }
            )
        }

        Spacer(Modifier.height(10.dp))

        // Quick summary row: date / time / options toggle
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SummaryChip(
                icon = Icons.Rounded.CalendarMonth,
                text = dueDate?.let { formatter.relativeDate(it) } ?: stringResource(R.string.no_date),
                onClick = { showDatePicker = !showDatePicker }
            )
            SummaryChip(
                icon = Icons.Rounded.Schedule,
                text = dueTime?.let { formatter.time(it) } ?: stringResource(R.string.time),
                onClick = { showTimePicker = true }
            )
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { expanded = !expanded }) {
                Text(
                    stringResource(if (expanded) R.string.less_options else R.string.more_options),
                    style = MaterialTheme.typography.labelMedium
                )
                Icon(
                    if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                    contentDescription = null
                )
            }
        }

        AnimatedVisibility(
            visible = showDatePicker,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(8.dp))
                InlineCalendarPicker(
                    formatter = formatter,
                    selected = dueDate ?: defaultDate,
                    onSelect = {
                        dueDate = it
                        showDatePicker = false
                    }
                )
                if (dueDate != null) {
                    TextButton(onClick = { dueDate = null; showDatePicker = false }) {
                        Text(stringResource(R.string.remove_date))
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = showTimePicker,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(8.dp))
                TimeWheelPicker(
                    formatter = formatter,
                    minutesOfDay = dueTime ?: defaultTimeMinutes(),
                    onChange = { dueTime = it }
                )
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { showTimePicker = false }) {
                        Text(stringResource(R.string.close))
                    }
                    TextButton(onClick = { dueTime = null; showTimePicker = false }) {
                        Text(stringResource(R.string.reminder_off))
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 76.dp),
                    placeholder = { Text(stringResource(R.string.task_description_hint)) },
                    label = { Text(stringResource(R.string.task_description)) },
                    shape = RoundedCornerShape(16.dp),
                    maxLines = 3,
                    colors = fieldColors()
                )

                Spacer(Modifier.height(14.dp))
                FieldLabel(stringResource(R.string.category))
                ChipRow(
                    items = categories,
                    selected = categories.firstOrNull { it.id == categoryId },
                    onSelect = { categoryId = if (categoryId == it.id) null else it.id },
                    label = { it.displayName() },
                    leading = { it.icon },
                    accent = { androidx.compose.ui.graphics.Color(it.color) },
                    contentPadding = PaddingValues(horizontal = 0.dp),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(14.dp))
                FieldLabel(stringResource(R.string.priority))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Priority.entries.forEach { level ->
                        SelectableChip(
                            text = stringResource(
                                when (level) {
                                    Priority.LOW -> R.string.priority_low
                                    Priority.MEDIUM -> R.string.priority_medium
                                    Priority.HIGH -> R.string.priority_high
                                }
                            ),
                            selected = priority == level,
                            accent = when (level) {
                                Priority.LOW -> colors.priorityLow
                                Priority.MEDIUM -> colors.priorityMedium
                                Priority.HIGH -> colors.priorityHigh
                            },
                            onClick = { priority = level }
                        )
                    }
                }

                Spacer(Modifier.height(14.dp))
                FieldLabel(stringResource(R.string.repeat))
                RepeatPicker(
                    formatter = formatter,
                    value = repeat,
                    onChange = { repeatRaw = it.serialize() }
                )

                Spacer(Modifier.height(14.dp))
                val reminderDate = dueDate
                ReminderRow(
                    enabled = reminder,
                    label = if (reminder)
                        stringResource(
                            R.string.reminder_at,
                            // No date means the reminder is for today.
                            formatter.relativeDate(reminderDate ?: LocalDate.now()),
                            formatter.time(dueTime ?: defaultReminderMinutes())
                        )
                    else stringResource(R.string.reminder_off),
                    onToggle = { wanted ->
                        reminder = wanted
                        // Ask exactly when the user opts in, so a reminder can
                        // never be saved that the system would silently block.
                        if (wanted) onReminderEnabled()
                    }
                )
            }
        }

        Spacer(Modifier.height(18.dp))
        Button(
            onClick = {
                keyboard?.hide()
                onSave(
                    TaskDraft(
                        id = editing?.id ?: 0L,
                        title = title,
                        description = description,
                        categoryId = categoryId,
                        dueDate = dueDate,
                        dueTimeMinutes = dueTime,
                        priority = priority,
                        reminderEnabled = reminder,
                        repeat = repeat
                    )
                )
            },
            enabled = canSave,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.coral,
                contentColor = androidx.compose.ui.graphics.Color.White
            )
        ) {
            Text(stringResource(R.string.save_task), style = MaterialTheme.typography.labelLarge)
        }
    }
}

private fun defaultTimeMinutes(): Int {
    val now = LocalTime.now()
    val rounded = ((now.hour * 60 + now.minute) / 5 + 1) * 5
    return rounded.coerceIn(0, 23 * 60 + 55)
}

private fun defaultReminderMinutes(): Int = 9 * 60

@Composable
private fun FieldLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = App2Theme.colors.textSecondary,
        modifier = Modifier.padding(bottom = 6.dp)
    )
}

@Composable
private fun SummaryChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
    onClick: () -> Unit
) {
    val colors = App2Theme.colors
    androidx.compose.material3.Surface(
        onClick = onClick,
        color = colors.surfaceMuted,
        shape = RoundedCornerShape(14.dp)
    ) {
        Row(
            Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, contentDescription = null, tint = colors.textSecondary, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(text, style = MaterialTheme.typography.labelMedium, color = colors.textPrimary)
        }
    }
}

@Composable
private fun ReminderRow(enabled: Boolean, label: String, onToggle: (Boolean) -> Unit) {
    val colors = App2Theme.colors
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Rounded.NotificationsActive,
                contentDescription = null,
                tint = colors.textSecondary,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(8.dp))
            Column {
                Text(
                    stringResource(R.string.reminder),
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.textPrimary
                )
                Text(label, style = MaterialTheme.typography.labelSmall, color = colors.textSecondary)
            }
        }
        Switch(
            checked = enabled,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(
                checkedThumbColor = androidx.compose.ui.graphics.Color.White,
                checkedTrackColor = colors.coral
            )
        )
    }
}

@Composable
private fun fieldColors() = TextFieldDefaults.colors(
    focusedContainerColor = App2Theme.colors.surfaceMuted,
    unfocusedContainerColor = App2Theme.colors.surfaceMuted,
    disabledContainerColor = App2Theme.colors.surfaceMuted,
    focusedIndicatorColor = App2Theme.colors.coral,
    unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
    cursorColor = App2Theme.colors.coral,
    focusedLabelColor = App2Theme.colors.coral,
    unfocusedLabelColor = App2Theme.colors.textSecondary
)
