package com.javidstudio.app2.ui.notes

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.R
import com.javidstudio.app2.data.repo.DefaultNotebooks
import com.javidstudio.app2.data.repo.Note
import com.javidstudio.app2.data.repo.Notebook
import com.javidstudio.app2.ui.components.SelectableChip
import com.javidstudio.app2.ui.theme.App2Theme

/** What the editor hands back on save. */
data class NoteDraft(
    val id: Long,
    val title: String,
    val body: String,
    val notebookId: Long?,
    val color: Int,
    val pinned: Boolean
)

/**
 * Note editor. Title and body only by default — the notebook and colour are
 * right there but never block writing something down quickly.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteEditorSheet(
    sheetState: SheetState,
    editing: Note?,
    notebooks: List<Notebook>,
    defaultNotebookId: Long?,
    onDismiss: () -> Unit,
    onSave: (NoteDraft) -> Unit
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
        NoteEditorContent(
            editing = editing,
            notebooks = notebooks,
            defaultNotebookId = defaultNotebookId,
            onSave = onSave
        )
    }
}

@Composable
private fun NoteEditorContent(
    editing: Note?,
    notebooks: List<Notebook>,
    defaultNotebookId: Long?,
    onSave: (NoteDraft) -> Unit
) {
    val colors = App2Theme.colors
    val keyboard = LocalSoftwareKeyboardController.current

    var title by rememberSaveable(editing?.id) { mutableStateOf(editing?.title ?: "") }
    var body by rememberSaveable(editing?.id) { mutableStateOf(editing?.body ?: "") }
    var notebookId by rememberSaveable(editing?.id) {
        mutableStateOf(editing?.notebook?.id ?: defaultNotebookId)
    }
    var color by rememberSaveable(editing?.id) { mutableStateOf(editing?.color ?: 0) }
    val pinned = editing?.pinned ?: false

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        if (editing == null) {
            kotlinx.coroutines.delay(120)
            runCatching { focusRequester.requestFocus() }
        }
    }

    val canSave = title.isNotBlank() || body.isNotBlank()

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
            stringResource(if (editing == null) R.string.new_note else R.string.edit_note),
            style = MaterialTheme.typography.titleMedium,
            color = colors.textPrimary
        )
        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            placeholder = { Text(stringResource(R.string.note_title_hint)) },
            label = { Text(stringResource(R.string.note_title)) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(10.dp))

        OutlinedTextField(
            value = body,
            onValueChange = { body = it },
            modifier = Modifier.fillMaxWidth().heightIn(min = 140.dp),
            placeholder = { Text(stringResource(R.string.note_body_hint)) },
            label = { Text(stringResource(R.string.note_body)) },
            shape = RoundedCornerShape(16.dp),
            colors = fieldColors()
        )

        Spacer(Modifier.height(16.dp))
        FieldLabel(stringResource(R.string.note_notebook))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                SelectableChip(
                    text = stringResource(R.string.loose_notes),
                    selected = notebookId == null,
                    accent = colors.textSecondary,
                    onClick = { notebookId = null }
                )
            }
            items(notebooks.size) { index ->
                val book = notebooks[index]
                val label = DefaultNotebooks.labelRes(book.builtInKey)
                    ?.let { stringResource(it) } ?: book.rawName
                SelectableChip(
                    text = label,
                    selected = notebookId == book.id,
                    accent = Color(book.color),
                    leading = book.icon,
                    onClick = { notebookId = book.id }
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        FieldLabel(stringResource(R.string.note_color))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                // 0 = follow the notebook's colour.
                ColorDot(
                    color = colors.surfaceMuted,
                    selected = color == 0,
                    onClick = { color = 0 }
                )
            }
            items(DefaultNotebooks.palette.size) { index ->
                val option = DefaultNotebooks.palette[index]
                ColorDot(
                    color = Color(option),
                    selected = color == option,
                    onClick = { color = option }
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                keyboard?.hide()
                onSave(
                    NoteDraft(
                        id = editing?.id ?: 0L,
                        title = title,
                        body = body,
                        notebookId = notebookId,
                        color = color,
                        pinned = pinned
                    )
                )
            },
            enabled = canSave,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.coral,
                contentColor = Color.White
            )
        ) {
            Text(stringResource(R.string.note_save), style = MaterialTheme.typography.labelLarge)
        }
    }
}

@Composable
private fun ColorDot(color: Color, selected: Boolean, onClick: () -> Unit) {
    val colors = App2Theme.colors
    Box(
        Modifier
            .size(36.dp)
            .background(color, CircleShape)
            .then(
                if (selected) Modifier.border(3.dp, colors.textPrimary.copy(alpha = 0.7f), CircleShape)
                else Modifier.border(1.dp, colors.outline, CircleShape)
            )
            .clickable(onClick = onClick)
    )
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
