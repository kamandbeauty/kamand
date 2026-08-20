package com.studiojavid.memory.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.studiojavid.memory.R
import com.studiojavid.memory.data.local.Mood
import com.studiojavid.memory.ui.theme.MemoryTheme

/**
 * The emoji drawn for a mood.
 *
 * Emoji are not localizable text, so unlike every other user-visible string
 * these live in code: they are the same glyph in both locales, and putting
 * them in strings.xml would invite a translator to change one and break the
 * scale's meaning.
 */
val Mood.emoji: String
    get() = when (this) {
        Mood.UNSET -> "🫥"
        Mood.AWFUL -> "😞"
        Mood.BAD -> "🙁"
        Mood.OKAY -> "😐"
        Mood.GOOD -> "🙂"
        Mood.GREAT -> "😄"
    }

@Composable
fun Mood.label(): String = stringResource(
    when (this) {
        Mood.UNSET -> R.string.mood_unset
        Mood.AWFUL -> R.string.mood_awful
        Mood.BAD -> R.string.mood_bad
        Mood.OKAY -> R.string.mood_okay
        Mood.GOOD -> R.string.mood_good
        Mood.GREAT -> R.string.mood_great
    }
)

@Composable
fun Mood.color(): Color {
    val colors = MemoryTheme.colors
    return when (this) {
        Mood.UNSET -> colors.textSecondary
        Mood.AWFUL -> colors.coral
        Mood.BAD -> colors.orange
        Mood.OKAY -> colors.yellow
        Mood.GOOD -> colors.turquoise
        Mood.GREAT -> colors.mint
    }
}

/** The five real moods, in order. UNSET is a storage default, not a choice. */
val selectableMoods: List<Mood> =
    listOf(Mood.AWFUL, Mood.BAD, Mood.OKAY, Mood.GOOD, Mood.GREAT)

/**
 * Horizontal mood scale.
 *
 * Tapping the already-selected mood clears it: a page written before the user
 * knew how the day would end should be able to go back to having no mood
 * rather than being stuck with a wrong one.
 */
@Composable
fun MoodPicker(
    selected: Mood,
    onSelect: (Mood) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        selectableMoods.forEach { mood ->
            MoodOption(
                mood = mood,
                selected = mood == selected,
                onClick = { onSelect(if (mood == selected) Mood.UNSET else mood) }
            )
        }
    }
}

@Composable
private fun MoodOption(mood: Mood, selected: Boolean, onClick: () -> Unit) {
    val colors = MemoryTheme.colors
    val accent = mood.color()
    val label = mood.label()

    val background by animateColorAsState(
        if (selected) colors.tint(accent) else Color.Transparent,
        label = "moodBg"
    )
    val scale by animateFloatAsState(
        if (selected) 1.08f else 0.94f,
        spring(dampingRatio = 0.5f, stiffness = 420f),
        label = "moodScale"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(CircleShape)
            .clickable(onClick = onClick)
            .clearAndSetSemantics { contentDescription = label }
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .scale(scale)
                .clip(CircleShape)
                .background(background)
                .then(
                    if (selected) Modifier.border(2.dp, accent.copy(alpha = 0.6f), CircleShape)
                    else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(mood.emoji, fontSize = 26.sp)
        }
        Spacer(Modifier.height(4.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) colors.onTint(accent) else colors.textSecondary,
            textAlign = TextAlign.Center,
            maxLines = 1
        )
    }
}
