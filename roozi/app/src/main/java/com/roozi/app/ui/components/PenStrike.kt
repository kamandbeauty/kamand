package com.roozi.app.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import com.roozi.app.ui.today.CompletionAnimator

/**
 * Draws an animated strike-through with a small pen that enters, writes and
 * leaves — the app's signature completion gesture.
 *
 * The stroke is a real [Path] revealed through [PathMeasure], so the ink is
 * genuinely drawn rather than faded in, and it carries a slight downward bow
 * the way a hand-drawn line does.
 *
 * @param progress 0f = no line, 1f = fully struck through.
 * @param penProgress position of the pen along the line; when null the pen is
 *        not drawn (used for already-completed rows and for reduced motion).
 */
fun DrawScope.drawPenStrike(
    progress: Float,
    penProgress: Float?,
    color: Color,
    strokeWidthPx: Float
) {
    if (progress <= 0f) return

    val y = size.height / 2f
    val path = Path().apply {
        moveTo(0f, y)
        // A gentle bow keeps the line from looking machine-drawn.
        quadraticBezierTo(size.width / 2f, y + size.height * 0.06f, size.width, y)
    }

    val measure = PathMeasure().apply { setPath(path, false) }
    val drawn = Path()
    measure.getSegment(0f, measure.length * progress.coerceIn(0f, 1f), drawn, true)

    drawPath(
        path = drawn,
        color = color,
        style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round)
    )

    if (penProgress != null && penProgress > 0f && penProgress < 1f) {
        val pos = measure.getPosition(measure.length * penProgress.coerceIn(0f, 1f))
        drawPenNib(pos, color, strokeWidthPx)
    }
}

/** A compact, elegant nib — deliberately not a cartoon pen. */
private fun DrawScope.drawPenNib(tip: Offset, color: Color, strokeWidthPx: Float) {
    val len = strokeWidthPx * 7f
    val wide = strokeWidthPx * 2.1f

    rotate(degrees = -38f, pivot = tip) {
        // Barrel
        drawRoundRect(
            color = color,
            topLeft = Offset(tip.x - wide / 2f, tip.y - len),
            size = androidx.compose.ui.geometry.Size(wide, len * 0.78f),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(wide / 2f, wide / 2f)
        )
        // Tip
        val nib = Path().apply {
            moveTo(tip.x - wide / 2f, tip.y - len * 0.22f)
            lineTo(tip.x + wide / 2f, tip.y - len * 0.22f)
            lineTo(tip.x, tip.y)
            close()
        }
        drawPath(nib, color)
    }
}

/**
 * Runs the strike animation for a title and returns a [Modifier] that draws it.
 *
 * @param completed persisted state of the task.
 * @param animate true only for a genuine incomplete → complete transition.
 */
@Composable
fun rememberPenStrikeModifier(
    completed: Boolean,
    animate: Boolean,
    color: Color,
    strokeWidth: Dp = 2.dp
): Modifier {
    // Start already-struck when the row is rebuilt for a task that was completed
    // earlier, so scrolling or restarting never replays the animation.
    val line = remember { Animatable(if (completed) 1f else 0f) }
    val pen = remember { Animatable(if (completed) 1f else 0f) }

    LaunchedEffect(completed, animate) {
        if (completed) {
            if (animate) {
                // 1) pen glides in from the leading edge
                pen.snapTo(0f)
                line.snapTo(0f)
                pen.animateTo(
                    0.02f,
                    tween(CompletionAnimator.PEN_ENTER_MS, easing = LinearOutSlowInEasing)
                )
                // 2) it writes across the title, ink following the nib
                val draw = tween<Float>(CompletionAnimator.PEN_DRAW_MS, easing = FastOutSlowInEasing)
                coroutineScope {
                    launch { pen.animateTo(1f, draw) }
                    launch { line.animateTo(1f, draw) }
                }
                // 3) and lifts off
                pen.animateTo(1f, tween(CompletionAnimator.PEN_EXIT_MS))
            } else {
                line.snapTo(1f)
                pen.snapTo(1f)
            }
        } else {
            // Unchecking rubs the line out from the end.
            pen.snapTo(1f)
            line.animateTo(0f, tween(220, easing = FastOutSlowInEasing))
        }
    }

    // Animatable.value is already snapshot-backed, so reading it inside the
    // draw lambda keeps the redraw scoped to drawing (no recomposition).
    val showPenNib = animate && completed

    return Modifier.drawWithContent {
        drawContent()
        val penAt = pen.value
        drawPenStrike(
            progress = line.value,
            penProgress = if (showPenNib && penAt < 1f) penAt else null,
            color = color,
            strokeWidthPx = strokeWidth.toPx()
        )
    }
}
