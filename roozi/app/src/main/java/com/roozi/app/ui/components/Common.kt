package com.roozi.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.roozi.app.ui.theme.RooziTheme

/** The app's signature soft card. */
@Composable
fun RooziCard(
    modifier: Modifier = Modifier,
    color: Color = RooziTheme.colors.surface,
    shape: RoundedCornerShape = RoundedCornerShape(22.dp),
    contentPadding: PaddingValues = PaddingValues(16.dp),
    border: BorderStroke? = null,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier,
        color = color,
        shape = shape,
        shadowElevation = if (RooziTheme.colors.isDark) 0.dp else 3.dp,
        tonalElevation = 0.dp,
        border = border ?: if (RooziTheme.colors.isDark) BorderStroke(1.dp, RooziTheme.colors.outline) else null
    ) {
        Box(Modifier.padding(contentPadding)) { content() }
    }
}

/** Small rounded pill used for categories, priorities and times. */
@Composable
fun Pill(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    leading: String? = null
) {
    val colors = RooziTheme.colors
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(color, color.darken(0.12f))))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            if (leading != null) Text(leading, style = MaterialTheme.typography.labelMedium)
            Text(
                text = text,
                style = MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow()),
                color = Color.White,
                maxLines = 1
            )
        }
    }
}

/** Horizontally scrollable single-choice chips (filters, categories, priorities). */
@Composable
fun <T> ChipRow(
    items: List<T>,
    selected: T?,
    onSelect: (T) -> Unit,
    // These run inside composition (callers use stringResource / theme colours),
    // so they must be @Composable lambdas.
    label: @Composable (T) -> String,
    modifier: Modifier = Modifier,
    accent: @Composable (T) -> Color = { RooziTheme.colors.coral },
    leading: @Composable (T) -> String? = { null },
    contentPadding: PaddingValues = PaddingValues(horizontal = 20.dp)
) {
    // NOTE: the `items` parameter shadows the LazyListScope.items DSL function,
    // so the count-based overload is called explicitly on the scope receiver.
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = contentPadding
    ) {
        itemsIndexed(items) { _, item ->
            SelectableChip(
                text = label(item),
                selected = item == selected,
                accent = accent(item),
                leading = leading(item),
                onClick = { onSelect(item) }
            )
        }
    }
}

@Composable
fun SelectableChip(
    text: String,
    selected: Boolean,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leading: String? = null
) {
    val colors = RooziTheme.colors
    val background by animateColorAsState(
        if (selected) accent else colors.surfaceMuted,
        label = "chipBg"
    )
    val content by animateColorAsState(
        if (selected) Color.White else colors.textSecondary,
        label = "chipFg"
    )
    val scale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.98f,
        animationSpec = spring(dampingRatio = 0.6f),
        label = "chipScale"
    )
    val interaction = remember { MutableInteractionSource() }
    Surface(
        modifier = modifier
            .scale(scale)
            .defaultMinSize(minHeight = 40.dp)
            .selectable(
                selected = selected,
                interactionSource = interaction,
                indication = null,
                role = Role.RadioButton,
                onClick = onClick
            ),
        color = background,
        shape = CircleShape
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (leading != null) Text(leading, style = MaterialTheme.typography.labelLarge)
            Text(text, style = MaterialTheme.typography.labelLarge, color = content, maxLines = 1)
        }
    }
}

@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = RooziTheme.colors.textPrimary
        )
        trailing?.invoke()
    }
}

@Composable
fun EmptyState(
    emoji: String,
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // The mascot carries the brand; the emoji rides along as context.
        Box(contentAlignment = Alignment.BottomEnd) {
            RooziMascot(size = 78.dp)
            Text(
                emoji,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.offset(x = 6.dp, y = 2.dp)
            )
        }
        Spacer(Modifier.height(16.dp))
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            color = RooziTheme.colors.textPrimary,
            textAlign = TextAlign.Center
        )
        if (subtitle != null) {
            Spacer(Modifier.height(6.dp))
            Text(
                subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = RooziTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun IconLabel(icon: ImageVector, text: String, tint: Color = LocalContentColor.current) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, style = MaterialTheme.typography.labelMedium, color = tint)
    }
}

/** Soft drop shadow that keeps white text legible on a coloured fill. */
fun accentTextShadow(): Shadow = Shadow(
    color = Color(0x59000000),
    offset = Offset(0f, 2f),
    blurRadius = 4f
)

/** Slightly darker variant of a colour, used for subtle gradients. */
fun Color.darken(amount: Float): Color = Color(
    red = red * (1f - amount),
    green = green * (1f - amount),
    blue = blue * (1f - amount),
    alpha = alpha
)

/**
 * A solid, colour-filled card.
 *
 * Deliberately does NOT use [RooziCard]: that draws an elevation shadow, and a
 * translucent fill lets the shadow show through as a visible rectangle behind
 * the content. Here the fill is opaque and drawn directly, so coloured panels
 * stay clean and their white text reads well.
 */
@Composable
fun AccentCard(
    accent: Color,
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(22.dp),
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .clip(shape)
            .background(Brush.linearGradient(listOf(accent, accent.darken(0.12f))))
            .padding(contentPadding)
    ) { content() }
}
