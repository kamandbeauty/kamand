package com.roozi.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.data.local.Priority
import com.roozi.app.data.repo.Task
import com.roozi.app.ui.theme.RooziTheme
import androidx.compose.ui.res.stringResource

/**
 * A single task row.
 *
 * Swipe → mark as done, swipe ← delete (with undo). The gesture directions are
 * expressed in *visual* terms so they feel identical in RTL and LTR.
 */
@Composable
fun SwipeableTaskCard(
    task: Task,
    subtitle: String,
    categoryLabel: String?,
    priorityLabel: String,
    onToggle: () -> Unit,
    onClick: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null
) {
    val colors = RooziTheme.colors
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl

    val dismissState = rememberSwipeToDismissBoxState(
        positionalThreshold = { total -> total * 0.42f }
    )

    LaunchedEffect(dismissState.currentValue) {
        when (dismissState.currentValue) {
            SwipeToDismissBoxValue.StartToEnd -> {
                // Visually: swipe towards the "start" edge.
                if (rtl) onDelete() else onToggle()
                dismissState.snapTo(SwipeToDismissBoxValue.Settled)
            }

            SwipeToDismissBoxValue.EndToStart -> {
                if (rtl) onToggle() else onDelete()
                dismissState.snapTo(SwipeToDismissBoxValue.Settled)
            }

            SwipeToDismissBoxValue.Settled -> Unit
        }
    }

    SwipeToDismissBox(
        state = dismissState,
        modifier = modifier,
        backgroundContent = {
            val direction = dismissState.dismissDirection
            val deleting = if (rtl) direction == SwipeToDismissBoxValue.StartToEnd
            else direction == SwipeToDismissBoxValue.EndToStart
            val bg = if (deleting) colors.danger else colors.success
            val icon = if (deleting) Icons.Rounded.DeleteOutline else Icons.Rounded.Check
            val label = stringResource(if (deleting) R.string.action_delete else R.string.action_done)
            val alignment = when (direction) {
                SwipeToDismissBoxValue.StartToEnd -> Alignment.CenterStart
                else -> Alignment.CenterEnd
            }
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(22.dp))
                    .background(bg.copy(alpha = 0.16f))
                    .padding(horizontal = 24.dp),
                contentAlignment = alignment
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(icon, contentDescription = null, tint = bg)
                    Spacer(Modifier.width(8.dp))
                    Text(label, style = MaterialTheme.typography.labelLarge, color = bg)
                }
            }
        },
        content = {
            TaskCardContent(
                task = task,
                subtitle = subtitle,
                categoryLabel = categoryLabel,
                priorityLabel = priorityLabel,
                onToggle = onToggle,
                onClick = onClick,
                onLongClick = onLongClick
            )
        }
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TaskCardContent(
    task: Task,
    subtitle: String,
    categoryLabel: String?,
    priorityLabel: String,
    onToggle: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null
) {
    val colors = RooziTheme.colors
    val accent = task.category?.let { Color(it.color) } ?: colors.purple
    val contentAlpha by animateFloatAsState(if (task.isCompleted) 0.55f else 1f, label = "alpha")

    RooziCard(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AnimatedCheckbox(
                checked = task.isCompleted,
                accent = accent,
                onCheckedChange = { onToggle() }
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f).alpha(contentAlpha)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (task.category != null) {
                        Text(task.category.icon, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.width(6.dp))
                    }
                    Text(
                        text = task.title,
                        style = MaterialTheme.typography.titleSmall,
                        color = colors.textPrimary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textDecoration = if (task.isCompleted) TextDecoration.LineThrough else null,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                }
                if (task.description.isNotBlank()) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        task.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = colors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Spacer(Modifier.height(6.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary
                    )
                    if (categoryLabel != null) {
                        Dot(accent)
                        Text(
                            categoryLabel,
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.textSecondary
                        )
                    }
                    if (task.reminderEnabled) {
                        Icon(
                            Icons.Rounded.Notifications,
                            contentDescription = null,
                            tint = colors.textSecondary,
                            modifier = Modifier.size(13.dp)
                        )
                    }
                    if (task.isRepeating) {
                        Icon(
                            Icons.Rounded.Repeat,
                            contentDescription = null,
                            tint = colors.textSecondary,
                            modifier = Modifier.size(13.dp)
                        )
                    }
                }
            }
            Spacer(Modifier.width(8.dp))
            PriorityIndicator(task.priority, priorityLabel)
        }
    }
}

@Composable
private fun Dot(color: Color) {
    Box(Modifier.size(4.dp).background(color.copy(alpha = 0.6f), CircleShape))
}

/** Delightful springy checkbox with a drawn check mark. */
@Composable
fun AnimatedCheckbox(
    checked: Boolean,
    accent: Color,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val fill by animateColorAsState(
        if (checked) accent else Color.Transparent,
        label = "checkFill"
    )
    val borderColor by animateColorAsState(
        if (checked) accent else colors.textSecondary.copy(alpha = 0.45f),
        label = "checkBorder"
    )
    val scale by animateFloatAsState(
        targetValue = if (checked) 1f else 0.92f,
        animationSpec = spring(dampingRatio = 0.45f, stiffness = 500f),
        label = "checkScale"
    )
    val iconSize by animateDpAsState(if (checked) 17.dp else 0.dp, spring(dampingRatio = 0.5f), label = "checkIcon")
    val cd = stringResource(R.string.cd_toggle_task)

    Box(
        modifier = modifier
            .size(48.dp) // accessible touch target
            .clickable(
                interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                indication = null
            ) { onCheckedChange(!checked) }
            .semantics { contentDescription = cd },
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(26.dp)
                .scale(scale)
                .background(fill, CircleShape)
                .border(2.dp, borderColor, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Rounded.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(iconSize)
            )
        }
    }
}

@Composable
fun PriorityIndicator(priority: Priority, label: String, modifier: Modifier = Modifier) {
    val colors = RooziTheme.colors
    val color = when (priority) {
        Priority.LOW -> colors.priorityLow
        Priority.MEDIUM -> colors.priorityMedium
        Priority.HIGH -> colors.priorityHigh
    }
    val bars = when (priority) {
        Priority.LOW -> 1
        Priority.MEDIUM -> 2
        Priority.HIGH -> 3
    }
    Row(
        modifier = modifier.semantics { contentDescription = label },
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        repeat(3) { i ->
            Box(
                Modifier
                    .width(3.dp)
                    .height((7 + i * 4).dp)
                    .background(
                        if (i < bars) color else color.copy(alpha = 0.18f),
                        RoundedCornerShape(2.dp)
                    )
            )
        }
    }
}
