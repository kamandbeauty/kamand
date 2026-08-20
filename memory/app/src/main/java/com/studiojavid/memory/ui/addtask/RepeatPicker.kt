package com.studiojavid.memory.ui.addtask

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.studiojavid.memory.R
import com.studiojavid.memory.core.date.DateFormatter
import com.studiojavid.memory.core.recurrence.RecurrenceRule
import com.studiojavid.memory.ui.components.SelectableChip
import com.studiojavid.memory.ui.theme.MemoryTheme
import java.time.DayOfWeek

/**
 * Repeat selection kept deliberately flat: five chips, and a weekday strip that
 * only appears when "specific days" is chosen. No nested dialogs.
 */
@Composable
fun RepeatPicker(
    formatter: DateFormatter,
    value: RecurrenceRule,
    onChange: (RecurrenceRule) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = MemoryTheme.colors
    val persian = formatter.persian
    val weekdayLabels = formatter.weekdayHeaders()
    val order = remember(persian) { RecurrenceRule.weekdayOrder(persian) }

    // Remember the last weekday selection so toggling modes is not destructive.
    var lastDays by remember {
        mutableStateOf((value as? RecurrenceRule.Weekly)?.days ?: emptySet())
    }
    var everyN by remember {
        mutableStateOf((value as? RecurrenceRule.EveryNDays)?.days ?: 2)
    }

    val mode = when (value) {
        RecurrenceRule.None -> RepeatMode.NEVER
        RecurrenceRule.Daily -> RepeatMode.DAILY
        RecurrenceRule.Monthly -> RepeatMode.MONTHLY
        is RecurrenceRule.Weekly -> RepeatMode.WEEKDAYS
        is RecurrenceRule.EveryNDays -> RepeatMode.CUSTOM
    }

    Column(modifier.fillMaxWidth()) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(RepeatMode.entries.size) { index ->
                val entry = RepeatMode.entries[index]
                SelectableChip(
                    text = stringResource(entry.labelRes),
                    selected = mode == entry,
                    accent = colors.purple,
                    onClick = {
                        onChange(
                            when (entry) {
                                RepeatMode.NEVER -> RecurrenceRule.None
                                RepeatMode.DAILY -> RecurrenceRule.Daily
                                RepeatMode.WEEKDAYS -> RecurrenceRule.Weekly(
                                    lastDays.ifEmpty { setOf(DayOfWeek.SATURDAY) }
                                )

                                RepeatMode.MONTHLY -> RecurrenceRule.Monthly
                                RepeatMode.CUSTOM -> RecurrenceRule.EveryNDays(everyN)
                            }
                        )
                    }
                )
            }
        }

        AnimatedVisibility(
            visible = mode == RepeatMode.WEEKDAYS,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(10.dp))
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    order.forEachIndexed { index, day ->
                        val selected = (value as? RecurrenceRule.Weekly)?.days?.contains(day) == true
                        SelectableChip(
                            text = weekdayLabels.getOrElse(index) { "" },
                            selected = selected,
                            accent = colors.turquoise,
                            onClick = {
                                val current = (value as? RecurrenceRule.Weekly)?.days ?: emptySet()
                                val updated = if (selected) current - day else current + day
                                lastDays = updated
                                onChange(
                                    if (updated.isEmpty()) RecurrenceRule.Daily
                                    else RecurrenceRule.Weekly(updated)
                                )
                            },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = mode == RepeatMode.CUSTOM,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(10.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(9) { index ->
                        val n = index + 2
                        SelectableChip(
                            text = stringResource(R.string.repeat_every_n_days, formatter.digits(n)),
                            selected = everyN == n && mode == RepeatMode.CUSTOM,
                            accent = colors.mint,
                            onClick = {
                                everyN = n
                                onChange(RecurrenceRule.EveryNDays(n))
                            }
                        )
                    }
                }
            }
        }
    }
}

private enum class RepeatMode(val labelRes: Int) {
    NEVER(R.string.repeat_never),
    DAILY(R.string.repeat_daily),
    WEEKDAYS(R.string.repeat_weekdays),
    MONTHLY(R.string.repeat_monthly),
    CUSTOM(R.string.repeat_custom)
}

/** Human readable summary shown on task cards and in the sheet header. */
@Composable
fun RecurrenceRule.label(formatter: DateFormatter): String = when (this) {
    RecurrenceRule.None -> stringResource(R.string.repeat_never)
    RecurrenceRule.Daily -> stringResource(R.string.repeat_daily)
    RecurrenceRule.Monthly -> stringResource(R.string.repeat_monthly)
    is RecurrenceRule.EveryNDays -> stringResource(R.string.repeat_every_n_days, formatter.digits(days))
    is RecurrenceRule.Weekly -> {
        val order = RecurrenceRule.weekdayOrder(formatter.persian)
        val labels = formatter.weekdayHeaders()
        val names = order.mapIndexedNotNull { index, day ->
            if (day in days) labels.getOrNull(index) else null
        }
        val separator = stringResource(R.string.list_separator)
        stringResource(R.string.repeat_on_days, names.joinToString(separator))
    }
}
