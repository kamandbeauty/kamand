package com.studiojavid.memory.ui.addtask

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.studiojavid.memory.core.date.DateFormatter
import com.studiojavid.memory.ui.theme.MemoryTheme
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Simple snapping wheel used for hours & minutes.
 *
 * Digits follow the UI locale, but the hour/minute order is fixed left-to-right
 * so it matches how the resulting time is displayed everywhere else.
 */
@Composable
fun TimeWheelPicker(
    formatter: DateFormatter,
    minutesOfDay: Int,
    onChange: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors

    // A clock always reads hours-then-minutes from the left, exactly like the
    // HH:MM text this picker edits. Under RTL a plain Row puts the hour wheel
    // on the right, so the two disagreed and the columns looked swapped.
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(
            modifier = modifier
                .fillMaxWidth()
                .background(colors.surfaceMuted, RoundedCornerShape(18.dp))
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Wheel(
                count = 24,
                selected = minutesOfDay / 60,
                label = { formatter.digits(it.toString().padStart(2, '0')) },
                onSelect = { onChange(it * 60 + minutesOfDay % 60) },
                modifier = Modifier.width(72.dp)
            )
            Text(
                ":",
                style = MaterialTheme.typography.titleLarge,
                color = colors.textSecondary,
                modifier = Modifier.padding(horizontal = 6.dp)
            )
            Wheel(
                count = 12,
                selected = (minutesOfDay % 60) / 5,
                label = { formatter.digits((it * 5).toString().padStart(2, '0')) },
                onSelect = { onChange((minutesOfDay / 60) * 60 + it * 5) },
                modifier = Modifier.width(72.dp)
            )
        }
    }
}

@Composable
private fun Wheel(
    count: Int,
    selected: Int,
    label: (Int) -> String,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    val itemHeight = 40.dp
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = selected)

    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()
            .collect { index -> if (index in 0 until count) onSelect(index) }
    }

    val centerIndex by remember { derivedStateOf { listState.firstVisibleItemIndex } }

    Box(modifier = modifier.height(itemHeight * 3), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(itemHeight)
                .background(colors.tint(colors.coral), RoundedCornerShape(12.dp))
        )
        LazyColumn(
            state = listState,
            modifier = Modifier.height(itemHeight * 3),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = itemHeight),
            flingBehavior = androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior(listState)
        ) {
            items(count) { index ->
                val isSelected = index == centerIndex
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(itemHeight),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = label(index),
                        style = if (isSelected) MaterialTheme.typography.titleMedium
                        else MaterialTheme.typography.bodyMedium,
                        color = if (isSelected) colors.textPrimary else colors.textSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.alpha(if (isSelected) 1f else 0.55f)
                    )
                }
            }
        }
    }
}
