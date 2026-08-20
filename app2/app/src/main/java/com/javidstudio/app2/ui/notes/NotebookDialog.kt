package com.javidstudio.app2.ui.notes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.javidstudio.app2.R
import com.javidstudio.app2.data.repo.DefaultNotebooks
import com.javidstudio.app2.data.repo.Notebook
import com.javidstudio.app2.ui.theme.App2Theme

/**
 * Create or edit a notebook, with a live preview of the book itself so the
 * cover choice is obvious before saving.
 */
@Composable
fun NotebookDialog(
    editing: Notebook?,
    onDismiss: () -> Unit,
    onConfirm: (name: String, icon: String, color: Int) -> Unit,
    onDelete: (() -> Unit)? = null
) {
    val colors = App2Theme.colors
    val builtInLabel = editing?.builtInKey?.let { DefaultNotebooks.labelRes(it) }
        ?.let { stringResource(it) }

    var name by remember { mutableStateOf(builtInLabel ?: editing?.rawName ?: "") }
    var icon by remember { mutableStateOf(editing?.icon ?: DefaultNotebooks.covers.first()) }
    var color by remember { mutableStateOf(editing?.color ?: DefaultNotebooks.palette.first()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(stringResource(if (editing == null) R.string.new_notebook else R.string.notebook_name))
        },
        text = {
            Column {
                // Live preview
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    BookCover(color = Color(color), width = 76.dp, height = 94.dp)
                }
                Spacer(Modifier.height(14.dp))

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    label = { Text(stringResource(R.string.notebook_name)) }
                )

                Spacer(Modifier.height(12.dp))
                Text(
                    stringResource(R.string.notebook_cover),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.textSecondary
                )
                Spacer(Modifier.height(6.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(DefaultNotebooks.covers.size) { index ->
                        val option = DefaultNotebooks.covers[index]
                        Box(
                            Modifier
                                .size(38.dp)
                                .background(
                                    if (option == icon) colors.tint(Color(color)) else colors.surfaceMuted,
                                    CircleShape
                                )
                                .clickable { icon = option },
                            contentAlignment = Alignment.Center
                        ) { Text(option) }
                    }
                }

                Spacer(Modifier.height(12.dp))
                Text(
                    stringResource(R.string.note_color),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.textSecondary
                )
                Spacer(Modifier.height(6.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(DefaultNotebooks.palette.size) { index ->
                        val option = DefaultNotebooks.palette[index]
                        Box(
                            Modifier
                                .size(32.dp)
                                .background(Color(option), CircleShape)
                                .then(
                                    if (option == color)
                                        Modifier.border(3.dp, colors.textPrimary.copy(alpha = 0.7f), CircleShape)
                                    else Modifier
                                )
                                .clickable { color = option }
                        )
                    }
                }

                if (onDelete != null) {
                    Spacer(Modifier.height(14.dp))
                    Text(
                        stringResource(R.string.notebook_delete_hint),
                        style = MaterialTheme.typography.labelSmall,
                        color = colors.textSecondary
                    )
                    TextButton(onClick = onDelete) {
                        Text(
                            stringResource(R.string.notebook_delete),
                            color = colors.danger,
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { if (name.isNotBlank()) onConfirm(name, icon, color) },
                enabled = name.isNotBlank()
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
        containerColor = colors.surface,
        shape = RoundedCornerShape(24.dp)
    )
}
