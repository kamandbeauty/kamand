package com.roozi.app.ui.components

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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.roozi.app.ui.theme.RooziTheme

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
    size: androidx.compose.ui.unit.Dp = 112.dp,
    strokeWidth: androidx.compose.ui.unit.Dp = 12.dp
) {
    val colors = RooziTheme.colors
    val animated by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 180f),
        label = "progress"
    )
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val track = colors.surfaceMuted
    val brush = Brush.sweepGradient(
        listOf(colors.coral, colors.orange, colors.yellow, colors.mint, colors.purple, colors.coral)
    )

    Box(
        modifier = modifier
            .size(size)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.size(size)) {
            val stroke = strokeWidth.toPx()
            val inset = stroke / 2f
            val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
            drawArc(
                color = track,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
            if (animated > 0f) {
                drawArc(
                    brush = brush,
                    startAngle = -90f,
                    sweepAngle = 360f * animated * if (rtl) -1f else 1f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                centerTop,
                style = MaterialTheme.typography.titleLarge,
                color = colors.textPrimary
            )
            Text(
                centerBottom,
                style = MaterialTheme.typography.labelMedium,
                color = colors.textSecondary
            )
        }
    }
}

/** Slim animated bar used in the weekly stats chart. */
@Composable
fun WeeklyBars(
    values: List<Float>,
    labels: List<String>,
    modifier: Modifier = Modifier,
    barHeight: androidx.compose.ui.unit.Dp = 92.dp
) {
    val colors = RooziTheme.colors
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
                Box(
                    modifier = Modifier
                        .size(width = 22.dp, height = barHeight),
                    contentAlignment = Alignment.BottomCenter
                ) {
                    Canvas(Modifier.size(width = 22.dp, height = barHeight)) {
                        val radius = 11.dp.toPx()
                        drawRoundRect(
                            color = track(colors.surfaceMuted),
                            cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius, radius)
                        )
                        val h = this.size.height * value
                        if (h > 1f) {
                            drawRoundRect(
                                brush = Brush.verticalGradient(
                                    listOf(colors.coral, colors.purple),
                                    startY = this.size.height - h,
                                    endY = this.size.height
                                ),
                                topLeft = Offset(0f, this.size.height - h),
                                size = Size(this.size.width, h),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius, radius)
                            )
                        }
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

private fun track(color: androidx.compose.ui.graphics.Color) = color
