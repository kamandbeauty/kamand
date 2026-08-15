package com.roozi.app.ui.alarm

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Snooze
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme

/**
 * The alarm-style reminder that fills the screen when a task comes due.
 *
 * A shade notification is easy to miss; this is the same treatment a phone call
 * or an alarm clock gets, so a reminder the user explicitly set cannot slip by.
 * Two exits only — snooze or acknowledge — because anything more turns an
 * interruption into a decision.
 */
@Composable
fun AlarmScreen(
    title: String,
    time: String,
    snoozeLabel: String,
    onSnooze: () -> Unit,
    onGotIt: () -> Unit,
    animate: Boolean = true
) {
    val colors = RooziTheme.colors

    // A slow pulse reads as "still ringing" without the strobing that a fast
    // animation would cause on a screen that may be the first thing seen after
    // waking up.
    val transition = rememberInfiniteTransition(label = "alarm")
    val pulse by transition.animateFloat(
        initialValue = if (animate) 0.94f else 1f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Box(
        Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(colors.gradientStart, colors.gradientEnd, colors.purple)
                )
            )
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .padding(horizontal = 28.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.weight(0.7f))

            Box(
                Modifier
                    .size(124.dp)
                    .graphicsLayer { scaleX = pulse; scaleY = pulse }
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.18f))
                    .border(2.dp, Color.White.copy(alpha = 0.42f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text("⏰", style = MaterialTheme.typography.displayMedium)
            }

            Spacer(Modifier.height(28.dp))

            Text(
                stringResource(R.string.alarm_now),
                style = MaterialTheme.typography.titleSmall,
                color = Color.White.copy(alpha = 0.86f)
            )

            Spacer(Modifier.height(10.dp))

            Text(
                title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(14.dp))

            Text(
                time,
                style = MaterialTheme.typography.titleLarge,
                color = Color.White.copy(alpha = 0.92f)
            )

            Spacer(Modifier.weight(1f))

            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                AlarmButton(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Rounded.Snooze,
                    label = stringResource(R.string.alarm_snooze),
                    sublabel = snoozeLabel,
                    filled = false,
                    onClick = onSnooze
                )
                AlarmButton(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Rounded.Check,
                    label = stringResource(R.string.alarm_got_it),
                    sublabel = null,
                    filled = true,
                    onClick = onGotIt
                )
            }
        }
    }
}

@Composable
private fun AlarmButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    sublabel: String?,
    filled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(24.dp)
    val background = if (filled) Color.White else Color.White.copy(alpha = 0.16f)
    val content = if (filled) RooziTheme.colors.purple else Color.White

    Column(
        modifier
            .clip(shape)
            .background(background, shape)
            .then(
                if (filled) Modifier
                else Modifier.border(1.5.dp, Color.White.copy(alpha = 0.42f), shape)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(8.dp))
        Text(
            label,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = content
        )
        if (sublabel != null) {
            Spacer(Modifier.height(2.dp))
            Text(
                sublabel,
                style = MaterialTheme.typography.labelSmall,
                color = content.copy(alpha = 0.8f)
            )
        }
    }
}
