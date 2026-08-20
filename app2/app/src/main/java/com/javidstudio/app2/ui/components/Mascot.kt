package com.javidstudio.app2.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.ui.theme.App2Theme

/**
 * "اپ" — the brand mascot: a small rounded check-card with eyes.
 *
 * It is deliberately a character version of the app icon rather than an
 * unrelated animal, so a single glance ties the empty state back to the brand.
 * Kept small and geometric to avoid a childish look.
 *
 * @param blink when true the mascot blinks slowly; disable for reduced motion.
 */
@Composable
fun App2Mascot(
    modifier: Modifier = Modifier,
    size: Dp = 76.dp,
    blink: Boolean = true
) {
    val colors = App2Theme.colors

    val transition = rememberInfiniteTransition(label = "mascot")
    val blinkPhase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 3200),
            repeatMode = RepeatMode.Restart
        ),
        label = "blink"
    )

    // Eyes are open for most of the cycle, closing briefly near the end.
    val eyeOpen = if (!blink) 1f else when {
        blinkPhase > 0.94f -> 0.12f
        blinkPhase > 0.90f -> 0.5f
        else -> 1f
    }

    Canvas(modifier.size(size)) {
        val s = this.size.minDimension
        val body = Size(s * 0.86f, s * 0.72f)
        val topLeft = Offset((s - body.width) / 2f, (s - body.height) / 2f)

        // Body: the icon's rounded card, in the brand gradient.
        drawRoundRect(
            brush = Brush.linearGradient(
                listOf(colors.coral, colors.purple),
                start = Offset(topLeft.x, topLeft.y),
                end = Offset(topLeft.x + body.width, topLeft.y + body.height)
            ),
            topLeft = topLeft,
            size = body,
            cornerRadius = CornerRadius(s * 0.24f, s * 0.24f)
        )

        // Eyes
        val eyeY = topLeft.y + body.height * 0.42f
        val eyeR = s * 0.055f
        listOf(-1f, 1f).forEach { side ->
            val cx = topLeft.x + body.width / 2f + side * body.width * 0.19f
            if (eyeOpen > 0.4f) {
                drawCircle(Color.White, radius = eyeR, center = Offset(cx, eyeY))
            } else {
                drawLine(
                    color = Color.White,
                    start = Offset(cx - eyeR, eyeY),
                    end = Offset(cx + eyeR, eyeY),
                    strokeWidth = s * 0.026f,
                    cap = StrokeCap.Round
                )
            }
        }

        // Smile: a small check mark, echoing the launcher icon.
        val cy = topLeft.y + body.height * 0.66f
        val w = body.width * 0.20f
        drawLine(
            color = Color.White,
            start = Offset(topLeft.x + body.width / 2f - w, cy),
            end = Offset(topLeft.x + body.width / 2f - w * 0.15f, cy + w * 0.55f),
            strokeWidth = s * 0.045f,
            cap = StrokeCap.Round
        )
        drawLine(
            color = Color.White,
            start = Offset(topLeft.x + body.width / 2f - w * 0.15f, cy + w * 0.55f),
            end = Offset(topLeft.x + body.width / 2f + w, cy - w * 0.35f),
            strokeWidth = s * 0.045f,
            cap = StrokeCap.Round
        )

        // Antenna dot — a touch of personality.
        drawLine(
            color = colors.purple,
            start = Offset(s / 2f, topLeft.y),
            end = Offset(s / 2f, topLeft.y - s * 0.10f),
            strokeWidth = s * 0.028f,
            cap = StrokeCap.Round
        )
        drawCircle(colors.yellow, radius = s * 0.055f, center = Offset(s / 2f, topLeft.y - s * 0.13f))
    }
}
