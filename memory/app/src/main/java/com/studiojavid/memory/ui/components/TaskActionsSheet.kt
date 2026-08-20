package com.studiojavid.memory.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EventBusy
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.NotificationsOff
import androidx.compose.material.icons.rounded.Today
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.studiojavid.memory.R
import com.studiojavid.memory.core.date.DateFormatter
import com.studiojavid.memory.data.repo.Task
import com.studiojavid.memory.ui.addtask.InlineCalendarPicker
import com.studiojavid.memory.ui.theme.MemoryTheme
import java.time.LocalDate

/**
 * Secondary actions for a task. Keeping these off the main list is what lets
 * the Today screen stay uncluttered while still exposing every operation.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskActionsSheet(
    sheetState: SheetState,
    task: Task,
    formatter: DateFormatter,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onToggleComplete: () -> Unit,
    onMoveTo: (LocalDate?) -> Unit,
    onToggleReminder: (Boolean) -> Unit,
    onDelete: () -> Unit
) {
    val colors = MemoryTheme.colors
    val today = remember { LocalDate.now() }
    var showPicker by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = {
            Box(
                Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(width = 42.dp, height = 5.dp)
                        .background(colors.textSecondary.copy(alpha = 0.3f), RoundedCornerShape(3.dp))
                )
            }
        }
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 16.dp)
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (task.category != null) {
                    Text(task.category.icon, style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.width(8.dp))
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        task.title,
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.textPrimary,
                        maxLines = 2
                    )
                    val subtitle = buildString {
                        append(
                            task.dueDate?.let { formatter.relativeDate(it) }
                                ?: stringResource(R.string.section_no_date)
                        )
                        task.dueTimeMinutes?.let { append(" · "); append(formatter.time(it)) }
                    }
                    Text(subtitle, style = MaterialTheme.typography.labelSmall, color = colors.textSecondary)
                }
            }

            Spacer(Modifier.height(14.dp))

            // Quick reschedule row
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                QuickDateChip(
                    icon = Icons.Rounded.Today,
                    label = stringResource(R.string.move_to_today),
                    accent = colors.coral,
                    modifier = Modifier.weight(1f)
                ) { onMoveTo(today) }
                QuickDateChip(
                    icon = Icons.Rounded.WbTwilight,
                    label = stringResource(R.string.move_to_tomorrow),
                    accent = colors.orange,
                    modifier = Modifier.weight(1f)
                ) { onMoveTo(today.plusDays(1)) }
            }

            Spacer(Modifier.height(8.dp))

            ActionRow(
                icon = Icons.Rounded.CalendarMonth,
                label = stringResource(R.string.pick_a_day),
                onClick = { showPicker = !showPicker }
            )

            AnimatedVisibility(
                visible = showPicker,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Column {
                    InlineCalendarPicker(
                        formatter = formatter,
                        selected = task.dueDate ?: today,
                        onSelect = { onMoveTo(it) }
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }

            if (task.dueDate != null) {
                ActionRow(
                    icon = Icons.Rounded.EventBusy,
                    label = stringResource(R.string.remove_date),
                    onClick = { onMoveTo(null) }
                )
            }

            ActionRow(
                icon = Icons.Rounded.Check,
                label = stringResource(
                    if (task.isCompleted) R.string.action_uncomplete else R.string.action_done
                ),
                onClick = onToggleComplete
            )

            ActionRow(
                icon = if (task.reminderEnabled) Icons.Rounded.NotificationsOff
                else Icons.Rounded.NotificationsActive,
                label = stringResource(
                    if (task.reminderEnabled) R.string.action_reminder_off
                    else R.string.action_reminder_on
                ),
                enabled = task.dueDate != null,
                onClick = { onToggleReminder(!task.reminderEnabled) }
            )

            ActionRow(
                icon = Icons.Rounded.Edit,
                label = stringResource(R.string.action_edit),
                onClick = onEdit
            )

            ActionRow(
                icon = Icons.Rounded.DeleteOutline,
                label = stringResource(R.string.action_delete),
                tint = colors.danger,
                onClick = onDelete
            )
        }
    }
}

@Composable
private fun QuickDateChip(
    icon: ImageVector,
    label: String,
    accent: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val colors = MemoryTheme.colors
    Column(
        modifier
            .background(colors.tint(accent), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = null, tint = colors.onTint(accent), modifier = Modifier.size(20.dp))
        Spacer(Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = colors.textPrimary)
    }
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    tint: Color? = null
) {
    val colors = MemoryTheme.colors
    val content = when {
        !enabled -> colors.textSecondary.copy(alpha = 0.4f)
        tint != null -> tint
        else -> colors.textPrimary
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(14.dp))
        Text(label, style = MaterialTheme.typography.bodyMedium, color = content)
    }
}
