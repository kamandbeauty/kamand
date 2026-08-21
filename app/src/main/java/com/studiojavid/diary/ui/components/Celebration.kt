package com.studiojavid.diary.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.studiojavid.diary.ui.theme.DiaryTheme
import kotlin.math.sin
import kotlin.random.Random

/**
 * A short, tasteful celebration shown once when the day is fully cleared.
 * ~30 confetti pieces for 1.6s — light enough for low-end devices.
 */
@Composable
fun CelebrationOverlay(
    visible: Boolean,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    val colors = DiaryTheme.colors
    val pieces = remember {
        val rnd = Random(7)
        List(30) {
            ConfettiPiece(
                x = rnd.nextFloat(),
                delay = rnd.nextFloat() * 0.25f,
                speed = 0.75f + rnd.nextFloat() * 0.5f,
                drift = (rnd.nextFloat() - 0.5f) * 0.25f,
                size = 6f + rnd.nextFloat() * 6f,
                colorIndex = rnd.nextInt(6)
            )
        }
    }
    val palette = listOf(colors.coral, colors.orange, colors.yellow, colors.mint, colors.turquoise, colors.purple)

    val t by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = if (visible) 1600 else 0, easing = LinearEasing),
        label = "confetti"
    )

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(180)) + scaleIn(initialScale = 0.9f),
        exit = fadeOut(tween(220)) + scaleOut(targetScale = 0.96f),
        modifier = modifier
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                pieces.forEach { p ->
                    val local = ((t - p.delay) * p.speed).coerceIn(0f, 1f)
                    if (local <= 0f) return@forEach
                    val y = size.height * local
                    val x = size.width * (p.x + p.drift * sin(local * 6f))
                    drawRect(
                        color = palette[p.colorIndex].copy(alpha = (1f - local).coerceIn(0f, 1f)),
                        topLeft = Offset(x, y),
                        size = Size(p.size, p.size * 1.6f)
                    )
                }
            }
            AccentCard(
                accent = colors.mint,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    // Mascot celebrates with the user (§20) — small, not childish.
                    DiaryMascot(size = 56.dp, blink = false)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        title,
                        style = MaterialTheme.typography.titleMedium.copy(shadow = accentTextShadow()),
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodyMedium.copy(shadow = accentTextShadow()),
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

private data class ConfettiPiece(
    val x: Float,
    val delay: Float,
    val speed: Float,
    val drift: Float,
    val size: Float,
    val colorIndex: Int
)

@Suppress("unused")
private val unusedColor = Color.Transparent
