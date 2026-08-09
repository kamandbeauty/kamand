package ir.factoryar.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits

/**
 * تقویم جلالی سفارشی (کاملاً آفلاین و بدون وابستگی بیرونی).
 * تاریخ انتخاب‌شده به‌صورت epoch millis (آغاز روز) برگردانده می‌شود.
 */
@Composable
fun JalaliDatePickerDialog(
    initialMillis: Long?,
    onDismiss: () -> Unit,
    onConfirm: (Long) -> Unit,
    title: String = "انتخاب تاریخ",
) {
    val today = remember { JalaliConverter.today() }
    var selected by remember { mutableStateOf(initialMillis?.let(JalaliConverter::fromEpochMillis) ?: today) }
    var displayYear by remember { mutableIntStateOf(selected.year) }
    var displayMonth by remember { mutableIntStateOf(selected.month) }

    fun shiftMonth(delta: Int) {
        var m = displayMonth + delta
        var y = displayYear
        if (m > 12) { m = 1; y++ }
        if (m < 1) { m = 12; y-- }
        displayMonth = m
        displayYear = y
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(
                    selected.format().toPersianDigits(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                // هدر ماه/سال
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    IconButton(onClick = { shiftMonth(1) }) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "ماه بعد")
                    }
                    Text(
                        "${JalaliDate.monthName(displayMonth)} ${displayYear.toString().toPersianDigits()}",
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.titleSmall,
                    )
                    IconButton(onClick = { shiftMonth(-1) }) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "ماه قبل")
                    }
                }
                Spacer(Modifier.height(4.dp))
                Row(Modifier.fillMaxWidth()) {
                    JalaliDate.WEEKDAY_LETTERS.forEach { letter ->
                        Text(
                            letter,
                            modifier = Modifier.weight(1f),
                            textAlign = TextAlign.Center,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Spacer(Modifier.height(4.dp))

                val daysInMonth = JalaliConverter.monthLength(displayYear, displayMonth)
                val firstWeekday = JalaliConverter.weekdayOf(JalaliDate(displayYear, displayMonth, 1))
                val cells = buildList<JalaliDate?> {
                    repeat(firstWeekday) { add(null) }
                    for (d in 1..daysInMonth) add(JalaliDate(displayYear, displayMonth, d))
                }

                LazyVerticalGrid(
                    columns = GridCells.Fixed(7),
                    modifier = Modifier.height(232.dp),
                    userScrollEnabled = false,
                ) {
                    items(cells.size) { index ->
                        val date = cells[index]
                        if (date == null) {
                            Box(Modifier.aspectRatio(1f))
                        } else {
                            val isSelected = date == selected
                            val isToday = date == today
                            Box(
                                modifier = Modifier
                                    .aspectRatio(1f)
                                    .padding(2.dp)
                                    .clip(MaterialTheme.shapes.small)
                                    .background(
                                        when {
                                            isSelected -> MaterialTheme.colorScheme.primary
                                            isToday -> MaterialTheme.colorScheme.primaryContainer
                                            else -> androidx.compose.ui.graphics.Color.Transparent
                                        },
                                    )
                                    .clickable { selected = date },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    date.day.toString().toPersianDigits(),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = when {
                                        isSelected -> MaterialTheme.colorScheme.onPrimary
                                        else -> MaterialTheme.colorScheme.onSurface
                                    },
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(JalaliConverter.toEpochMillis(selected)) }) { Text("تأیید") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
