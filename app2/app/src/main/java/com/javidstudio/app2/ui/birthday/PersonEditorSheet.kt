package com.javidstudio.app2.ui.birthday

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.R
import com.javidstudio.app2.core.date.DateFormatter
import com.javidstudio.app2.core.date.JalaliDate
import com.javidstudio.app2.core.util.PersianNumbers
import com.javidstudio.app2.data.repo.BirthdayAvatars
import com.javidstudio.app2.data.repo.BirthdayPerson
import com.javidstudio.app2.data.repo.ReminderOffsets
import com.javidstudio.app2.ui.components.SelectableChip
import com.javidstudio.app2.ui.theme.App2Theme

/** What the editor returns on save. */
data class PersonDraft(
    val id: Long,
    val name: String,
    val birthMonth: Int,
    val birthDay: Int,
    val birthYear: Int?,
    val relationship: String,
    val avatar: String,
    val notes: String,
    val reminderEnabled: Boolean,
    val reminderOffset: Int
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PersonEditorSheet(
    sheetState: SheetState,
    formatter: DateFormatter,
    editing: BirthdayPerson?,
    onDismiss: () -> Unit,
    onSave: (PersonDraft) -> Unit,
    onDelete: (() -> Unit)? = null
) {
    val colors = App2Theme.colors

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = {
            Box(
                Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(width = 42.dp, height = 5.dp)
                        .background(colors.textSecondary.copy(alpha = 0.3f), RoundedCornerShape(3.dp))
                )
            }
        }
    ) {
        PersonEditorContent(formatter, editing, onSave, onDelete)
    }
}

@Composable
private fun PersonEditorContent(
    formatter: DateFormatter,
    editing: BirthdayPerson?,
    onSave: (PersonDraft) -> Unit,
    onDelete: (() -> Unit)?
) {
    val colors = App2Theme.colors
    val keyboard = LocalSoftwareKeyboardController.current
    val todayJalali = remember { JalaliDate.now() }

    var name by rememberSaveable(editing?.id) { mutableStateOf(editing?.name ?: "") }
    var month by rememberSaveable(editing?.id) { mutableStateOf(editing?.birthMonth ?: todayJalali.month) }
    var day by rememberSaveable(editing?.id) { mutableStateOf(editing?.birthDay ?: todayJalali.day) }
    var yearText by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.birthYear?.toString() ?: "")
    }
    var relationship by rememberSaveable(editing?.id) { mutableStateOf(editing?.relationship ?: "") }
    var avatar by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.avatar ?: BirthdayAvatars.all.first())
    }
    var notes by rememberSaveable(editing?.id) { mutableStateOf(editing?.notes ?: "") }
    var reminderEnabled by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.reminderEnabled ?: false)
    }
    var reminderOffset by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.reminderOffset ?: 1)
    }
    var showDayPicker by rememberSaveable { mutableStateOf(false) }

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        if (editing == null) {
            kotlinx.coroutines.delay(120)
            runCatching { focusRequester.requestFocus() }
        }
    }

    val relationshipOptions = listOf(
        R.string.rel_mother, R.string.rel_father, R.string.rel_spouse, R.string.rel_child,
        R.string.rel_sister, R.string.rel_brother, R.string.rel_friend,
        R.string.rel_colleague, R.string.rel_relative, R.string.rel_other
    ).map { stringResource(it) }

    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 20.dp)
    ) {
        Text(
            stringResource(if (editing == null) R.string.add_birthday else R.string.edit_birthday),
            style = MaterialTheme.typography.titleMedium,
            color = colors.textPrimary
        )
        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            placeholder = { Text(stringResource(R.string.person_name_hint)) },
            label = { Text(stringResource(R.string.person_name)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(14.dp))
        FieldLabel(stringResource(R.string.avatar))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(BirthdayAvatars.all.size) { index ->
                val option = BirthdayAvatars.all[index]
                Box(
                    Modifier
                        .size(44.dp)
                        .background(
                            if (option == avatar) colors.tint(colors.coral) else colors.surfaceMuted,
                            CircleShape
                        )
                        .then(
                            if (option == avatar)
                                Modifier.border(2.dp, colors.coral, CircleShape) else Modifier
                        )
                        .clickable { avatar = option },
                    contentAlignment = Alignment.Center
                ) { Text(option, style = MaterialTheme.typography.titleMedium) }
            }
        }

        Spacer(Modifier.height(14.dp))
        FieldLabel(stringResource(R.string.birth_date))
        Box(
            Modifier
                .fillMaxWidth()
                .background(colors.surfaceMuted, RoundedCornerShape(16.dp))
                .clickable { showDayPicker = !showDayPicker }
                .padding(14.dp)
        ) {
            Text(
                formatter.jalaliDayMonth(month, day),
                style = MaterialTheme.typography.bodyMedium,
                color = colors.textPrimary
            )
        }

        AnimatedVisibility(
            visible = showDayPicker,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(8.dp))
                JalaliDayMonthPicker(
                    formatter = formatter,
                    month = month,
                    day = day,
                    onChange = { m, d -> month = m; day = d }
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        // Optional: without it, no age is shown anywhere.
        OutlinedTextField(
            value = yearText,
            onValueChange = { input ->
                // Accept Persian digits too, keep only numbers.
                yearText = PersianNumbers.toLatin(input).filter { it.isDigit() }.take(4)
            },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text(stringResource(R.string.birth_year_hint)) },
            label = { Text(stringResource(R.string.birth_year_optional)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(14.dp))
        FieldLabel(stringResource(R.string.relationship_optional))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(relationshipOptions.size) { index ->
                val option = relationshipOptions[index]
                SelectableChip(
                    text = option,
                    selected = relationship == option,
                    accent = colors.turquoise,
                    onClick = { relationship = if (relationship == option) "" else option }
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = relationship,
            onValueChange = { relationship = it },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text(stringResource(R.string.rel_custom_hint)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(14.dp))
        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            modifier = Modifier.fillMaxWidth().heightIn(min = 90.dp),
            placeholder = { Text(stringResource(R.string.person_notes_hint)) },
            label = { Text(stringResource(R.string.person_notes)) },
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(16.dp))
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                stringResource(R.string.birthday_reminder),
                style = MaterialTheme.typography.titleSmall,
                color = colors.textPrimary
            )
            Switch(
                checked = reminderEnabled,
                onCheckedChange = { reminderEnabled = it },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = colors.coral
                )
            )
        }

        AnimatedVisibility(
            visible = reminderEnabled,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column {
                Spacer(Modifier.height(8.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(ReminderOffsets.all.size) { index ->
                        val offset = ReminderOffsets.all[index]
                        SelectableChip(
                            text = if (offset == 0) stringResource(R.string.reminder_on_day)
                            else stringResource(
                                R.string.reminder_days_before,
                                formatter.digits(offset)
                            ),
                            selected = reminderOffset == offset,
                            accent = colors.orange,
                            onClick = { reminderOffset = offset }
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                keyboard?.hide()
                onSave(
                    PersonDraft(
                        id = editing?.id ?: 0L,
                        name = name,
                        birthMonth = month,
                        birthDay = day,
                        birthYear = yearText.toIntOrNull(),
                        relationship = relationship,
                        avatar = avatar,
                        notes = notes,
                        reminderEnabled = reminderEnabled,
                        reminderOffset = reminderOffset
                    )
                )
            },
            enabled = name.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.coral,
                contentColor = Color.White
            )
        ) {
            Text(stringResource(R.string.save_person), style = MaterialTheme.typography.labelLarge)
        }

        if (onDelete != null) {
            TextButton(
                onClick = onDelete,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.delete_person), color = colors.danger)
            }
        }
    }
}

/**
 * Month and day pickers for a recurring date — deliberately no year, since the
 * birth year is a separate optional field.
 */
@Composable
private fun JalaliDayMonthPicker(
    formatter: DateFormatter,
    month: Int,
    day: Int,
    onChange: (Int, Int) -> Unit
) {
    val colors = App2Theme.colors
    val months = formatter.jalaliMonthNames()
    // Day count follows the month; Esfand is clamped using a leap year so 30 is
    // selectable, and the repository clamps again when the year is not leap.
    val maxDay = remember(month) { JalaliDate.monthLength(1403, month) }

    Column {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(months.size) { index ->
                SelectableChip(
                    text = months[index],
                    selected = month == index + 1,
                    accent = colors.purple,
                    onClick = {
                        val newMonth = index + 1
                        val newMax = JalaliDate.monthLength(1403, newMonth)
                        onChange(newMonth, day.coerceAtMost(newMax))
                    }
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(maxDay) { index ->
                val d = index + 1
                SelectableChip(
                    text = formatter.digits(d),
                    selected = day == d,
                    accent = colors.coral,
                    onClick = { onChange(month, d) }
                )
            }
        }
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = App2Theme.colors.textSecondary,
        modifier = Modifier.padding(bottom = 6.dp)
    )
}

@Composable
private fun fieldColors() = TextFieldDefaults.colors(
    focusedContainerColor = App2Theme.colors.surfaceMuted,
    unfocusedContainerColor = App2Theme.colors.surfaceMuted,
    disabledContainerColor = App2Theme.colors.surfaceMuted,
    focusedIndicatorColor = App2Theme.colors.coral,
    unfocusedIndicatorColor = Color.Transparent,
    cursorColor = App2Theme.colors.coral,
    focusedLabelColor = App2Theme.colors.coral,
    unfocusedLabelColor = App2Theme.colors.textSecondary
)
