package com.studiojavid.memory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.studiojavid.memory.ui.theme.MemoryTheme

/**
 * Animated daily progress ring — the hero element of the Today screen.
 * The sweep animates with a gentle spring whenever a task is toggled.
 */
@Composable
fun ProgressRing(
    progress: Float,
    centerTop: String,
    centerBottom: String,
    contentDescription: String,
    modifier: Modifier = Modifier,
    ringSize: Dp = 112.dp,
    ringStroke: Dp = 12.dp,
    /** True when the ring sits on the coloured hero card. */
    onGradient: Boolean = false
) {
    val colors = MemoryTheme.colors
    val animated by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 180f),
        label = "progress"
    )
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    // On the gradient hero the ring is white-on-translucent so it stays legible
    // whatever the theme accent is; elsewhere it keeps the playful sweep.
    val track = if (onGradient) Color.White.copy(alpha = 0.28f) else colors.surfaceMuted
    val brush = if (onGradient) {
        Brush.sweepGradient(listOf(Color.White, Color.White))
    } else {
        Brush.sweepGradient(
            listOf(colors.coral, colors.orange, colors.yellow, colors.mint, colors.purple, colors.coral)
        )
    }
    val label = contentDescription

    Box(
        modifier = modifier
            .size(ringSize)
            .semantics { this.contentDescription = label },
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.size(ringSize)) {
            val strokePx = ringStroke.toPx()
            val inset = strokePx / 2f
            val arcSize = Size(size.width - strokePx, size.height - strokePx)
            drawArc(
                color = track,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = Stroke(width = strokePx, cap = StrokeCap.Round)
            )
            if (animated > 0f) {
                drawArc(
                    brush = brush,
                    startAngle = -90f,
                    sweepAngle = 360f * animated * if (rtl) -1f else 1f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = strokePx, cap = StrokeCap.Round)
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                centerTop,
                style = if (onGradient)
                    MaterialTheme.typography.titleLarge.copy(shadow = accentTextShadow())
                else MaterialTheme.typography.titleLarge,
                color = if (onGradient) Color.White else colors.textPrimary
            )
            Text(
                centerBottom,
                style = if (onGradient)
                    MaterialTheme.typography.labelMedium.copy(shadow = accentTextShadow())
                else MaterialTheme.typography.labelMedium,
                color = if (onGradient) Color.White.copy(alpha = 0.88f) else colors.textSecondary
            )
        }
    }
}

/** Slim animated bars used by the weekly statistics chart. */
@Composable
fun WeeklyBars(
    values: List<Float>,
    labels: List<String>,
    modifier: Modifier = Modifier,
    barHeight: Dp = 92.dp,
    barWidth: Dp = 22.dp
) {
    val colors = MemoryTheme.colors
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Bottom
    ) {
        values.forEachIndexed { index, raw ->
            val value by animateFloatAsState(
                targetValue = raw.coerceIn(0f, 1f),
                animationSpec = spring(dampingRatio = 0.8f, stiffness = 160f),
                label = "bar$index"
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Canvas(Modifier.size(width = barWidth, height = barHeight)) {
                    val radius = CornerRadius(size.width / 2f, size.width / 2f)
                    drawRoundRect(color = colors.surfaceMuted, cornerRadius = radius)
                    val filled = size.height * value
                    if (filled > 1f) {
                        drawRoundRect(
                            brush = Brush.verticalGradient(
                                colors = listOf(colors.coral, colors.purple),
                                startY = size.height - filled,
                                endY = size.height
                            ),
                            topLeft = Offset(0f, size.height - filled),
                            size = Size(size.width, filled),
                            cornerRadius = radius
                        )
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    labels.getOrElse(index) { "" },
                    style = MaterialTheme.typography.labelSmall,
                    color = colors.textSecondary
                )
            }
        }
    }
}
