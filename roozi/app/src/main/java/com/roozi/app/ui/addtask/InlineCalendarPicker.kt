package com.roozi.app.ui.addtask

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.roozi.app.R
import com.roozi.app.core.date.DateFormatter
import com.roozi.app.ui.components.RooziCalendar
import com.roozi.app.ui.components.SelectableChip
import com.roozi.app.ui.theme.RooziTheme
import java.time.LocalDate

/**
 * The very same Jalali calendar used on the Calendar tab, embedded in the
 * add-task sheet — the app never falls back to a Gregorian picker in Persian.
 */
@Composable
fun InlineCalendarPicker(
    formatter: DateFormatter,
    selected: LocalDate,
    onSelect: (LocalDate) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = RooziTheme.colors
    val today = remember { LocalDate.now() }
    var internal by remember { mutableStateOf(selected) }

    Column(
        modifier
            .fillMaxWidth()
            .background(colors.surfaceMuted, RoundedCornerShape(20.dp))
            .padding(12.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SelectableChip(
                text = stringResource(R.string.task_today),
                selected = internal == today,
                accent = colors.coral,
                onClick = { internal = today; onSelect(today) }
            )
            SelectableChip(
                text = stringResource(R.string.task_tomorrow),
                selected = internal == today.plusDays(1),
                accent = colors.purple,
                onClick = { internal = today.plusDays(1); onSelect(today.plusDays(1)) }
            )
        }
        Spacer(Modifier.height(8.dp))
        RooziCalendar(
            formatter = formatter,
            selectedDate = internal,
            onSelectDate = {
                internal = it
                onSelect(it)
            },
            loads = emptyMap(),
            onVisibleMonthChange = {},
            today = today
        )
    }
}
