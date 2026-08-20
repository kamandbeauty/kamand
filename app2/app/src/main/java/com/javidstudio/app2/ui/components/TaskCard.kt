package com.javidstudio.app2.ui.components

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
import androidx.compose.foundation.layout.absolutePadding
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
import androidx.compose.ui.AbsoluteAlignment
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
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.graphics.graphicsLayer
import com.javidstudio.app2.R
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.repo.Task
import com.javidstudio.app2.ui.theme.App2Theme
import androidx.compose.ui.res.stringResource

/**
 * A single task row.
 *
 * Swipe → mark as done, swipe ← delete (with undo). The gesture directions are
 * expressed in *visual* terms so they feel identical in RTL and LTR.
 */
/** Approximate width of the icon + label hint. */
private val HINT_WIDTH = 96.dp
private val HINT_MAX_INSET = 24.dp
private val HINT_FULLY_VISIBLE_AT = 72.dp

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
    onLongClick: (() -> Unit)? = null,
    /** True only for a genuine incomplete → complete transition. */
    animateCompletion: Boolean = false
) {
    val colors = App2Theme.colors
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl

    val dismissState = rememberSwipeToDismissBoxState(
        positionalThreshold = { total -> total * 0.42f }
    )

    // SwipeToDismissBox (material3 1.3.x) does not mirror the *gesture*: the
    // drag runs with reverseDirection = false and the content is placed at the
    // raw pixel offset, so a physical right-swipe always yields a positive
    // offset. What flips under RTL is only which enum value sits on which
    // anchor — StartToEnd is placed at -width and EndToStart at +width.
    //
    // dismissDirection is derived from the offset sign, so the background hint
    // below is already correct in both locales; currentValue is the anchor's
    // label, so acting on it directly inverts the gesture in Persian.
    //   card moved RIGHT -> done
    //   card moved LEFT  -> delete
    LaunchedEffect(dismissState.currentValue, rtl) {
        val settled = dismissState.currentValue
        if (settled == SwipeToDismissBoxValue.Settled) return@LaunchedEffect
        if (SwipeDirection.movedRight(settled == SwipeToDismissBoxValue.StartToEnd, rtl)) {
            onToggle()
        } else {
            onDelete()
        }
        dismissState.snapTo(SwipeToDismissBoxValue.Settled)
    }

    SwipeToDismissBox(
        state = dismissState,
        modifier = modifier,
        backgroundContent = {
            // dismissDirection is derived from the raw offset sign rather than
            // from the anchor labels, so it is the one signal that already means
            // the same thing in both layout directions.
            val offsetPx = runCatching { dismissState.requireOffset() }.getOrDefault(0f)
            val onLeft = offsetPx > 0f // card moved right -> the gap opens on the left

            val deleting = !onLeft
            val bg = if (deleting) colors.danger else colors.success
            val icon = if (deleting) Icons.Rounded.DeleteOutline else Icons.Rounded.Check
            val label = stringResource(if (deleting) R.string.action_delete else R.string.action_done)

            // AbsoluteAlignment keeps the side unambiguous under RTL.
            val alignment =
                if (onLeft) AbsoluteAlignment.CenterLeft else AbsoluteAlignment.CenterRight

            // The hint tracks the gap instead of sitting at a fixed inset.
            // Pinned at a fixed padding it only cleared the card near the end
            // of the gesture; following the revealed width makes it readable
            // from the first few pixels of the swipe.
            val revealed = with(LocalDensity.current) { abs(offsetPx).toDp() }
            val inset = (revealed - HINT_WIDTH).coerceIn(0.dp, HINT_MAX_INSET)
            val appear = (revealed.value / HINT_FULLY_VISIBLE_AT.value).coerceIn(0f, 1f)

            Box(
                Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(22.dp))
                    .background(bg.copy(alpha = 0.16f * appear.coerceAtLeast(0.35f)))
                    .padding(horizontal = 12.dp),
                contentAlignment = alignment
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .absolutePadding(
                            left = if (onLeft) inset else 0.dp,
                            right = if (onLeft) 0.dp else inset
                        )
                        .graphicsLayer {
                            alpha = appear
                            scaleX = 0.85f + 0.15f * appear
                            scaleY = 0.85f + 0.15f * appear
                        }
                ) {
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
                onLongClick = onLongClick,
                animateCompletion = animateCompletion
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
    onLongClick: (() -> Unit)? = null,
    animateCompletion: Boolean = false
) {
    val colors = App2Theme.colors
    val accent = task.category?.let { Color(it.color) } ?: colors.purple
    val contentAlpha by animateFloatAsState(if (task.isCompleted) 0.55f else 1f, label = "alpha")

    App2Card(
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
                        modifier = Modifier
                            .weight(1f, fill = false)
                            .then(
                                rememberPenStrikeModifier(
                                    completed = task.isCompleted,
                                    animate = animateCompletion,
                                    color = accent
                                )
                            )
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
    val colors = App2Theme.colors
    val fill by animateColorAsState(
        if (checked) accent else Color.Transparent,
        label = "checkFill"
    )
    val borderColor by animateColorAsState(
        if (checked) accent else colors.textSecondary.copy(alpha = 0.45f),
        label = "checkBorder"
    )
    // Short overshoot so ticking feels physical; reverses cleanly on uncheck.
    val scale by animateFloatAsState(
        targetValue = if (checked) 1f else 0.92f,
        animationSpec = spring(dampingRatio = 0.38f, stiffness = 900f),
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
    val colors = App2Theme.colors
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
