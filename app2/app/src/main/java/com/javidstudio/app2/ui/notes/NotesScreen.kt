package com.javidstudio.app2.ui.notes

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.javidstudio.app2.R
import com.javidstudio.app2.data.repo.DefaultNotebooks
import com.javidstudio.app2.data.repo.Note
import com.javidstudio.app2.data.repo.Notebook
import com.javidstudio.app2.ui.NoteFilter
import com.javidstudio.app2.ui.NotesViewModel
import com.javidstudio.app2.ui.components.EmptyState
import com.javidstudio.app2.ui.components.SectionHeader
import com.javidstudio.app2.ui.components.accentTextShadow
import com.javidstudio.app2.ui.components.darken
import com.javidstudio.app2.ui.theme.App2Theme
import com.javidstudio.app2.ui.theme.timeOfDayGradient
import java.time.LocalTime

/**
 * Notes tab: a shelf of notebooks on top, the notes of the current shelf below.
 *
 * Follows the same design language as Today — one gradient accent, rounded
 * cards, generous spacing — so the new tab does not read as a bolt-on.
 */
@Composable
fun NotesScreen(
    viewModel: NotesViewModel,
    onOpenNote: (Note?) -> Unit,
    onEditNotebook: (Notebook?) -> Unit,
    onOpenBirthdays: () -> Unit,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier
) {
    val colors = App2Theme.colors
    val notes by viewModel.notes.collectAsStateWithLifecycle()
    val notebooks by viewModel.notebooks.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val hour = androidx.compose.runtime.remember { LocalTime.now().hour }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors.timeOfDayGradient(hour))),
        contentPadding = PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 96.dp
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item(key = "shelfHeader") {
            SectionHeader(
                title = stringResource(R.string.notebooks_title),
                trailing = {
                    Box(
                        Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background(colors.tint(colors.purple))
                            .clickable { onEditNotebook(null) },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Rounded.Add,
                            contentDescription = stringResource(R.string.new_notebook),
                            tint = colors.onTint(colors.purple),
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            )
        }

        // The shelf: "all" first, then each notebook, then loose notes.
        item(key = "shelf") {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                // Always first: the birthday notebook is a destination, not a
                // filter, so it opens its own screen instead of filtering notes.
                item(key = "shelf-birthdays") {
                    BookShelfItem(
                        // No caption: the other shelves count notes, and this
                        // one had a tagline that described nothing.
                        title = stringResource(R.string.notebook_birthdays),
                        subtitle = "",
                        color = colors.pink,
                        selected = false,
                        onClick = onOpenBirthdays
                    )
                }
                item(key = "shelf-all") {
                    BookShelfItem(
                        title = stringResource(R.string.all_notes),
                        subtitle = stringResource(R.string.note_count, notes.size.localized()),
                        color = colors.coral,
                        selected = filter == NoteFilter.All,
                        onClick = { viewModel.setFilter(NoteFilter.All) }
                    )
                }
                items(notebooks, key = { "shelf-${it.id}" }) { book ->
                    BookShelfItem(
                        title = book.displayName(),
                        subtitle = stringResource(R.string.note_count, book.noteCount.localized()),
                        color = Color(book.color),
                        selected = filter == NoteFilter.InNotebook(book.id),
                        onClick = { viewModel.setFilter(NoteFilter.InNotebook(book.id)) }
                    )
                }
                item(key = "shelf-loose") {
                    BookShelfItem(
                        title = stringResource(R.string.loose_notes),
                        subtitle = "",
                        color = colors.textSecondary,
                        selected = filter == NoteFilter.Loose,
                        onClick = { viewModel.setFilter(NoteFilter.Loose) }
                    )
                }
            }
        }

        item(key = "notesHeader") {
            Spacer(Modifier.height(2.dp))
            val currentBook = (filter as? NoteFilter.InNotebook)
                ?.let { f -> notebooks.firstOrNull { it.id == f.notebookId } }
            SectionHeader(
                title = currentBook?.displayName() ?: stringResource(R.string.notes_title),
                trailing = {
                    if (currentBook != null) {
                        Text(
                            stringResource(R.string.notebook_delete),
                            style = MaterialTheme.typography.labelMedium,
                            color = colors.textSecondary,
                            modifier = Modifier.clickable { onEditNotebook(currentBook) }
                        )
                    }
                }
            )
        }

        if (notes.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    title = stringResource(
                        if (filter is NoteFilter.InNotebook) R.string.empty_notebook
                        else R.string.empty_notes
                    ),
                    subtitle = if (filter is NoteFilter.InNotebook) null
                    else stringResource(R.string.empty_notes_sub)
                )
            }
        } else {
            items(notes, key = { it.id }) { note ->
                NoteCard(
                    note = note,
                    onClick = { onOpenNote(note) },
                    onTogglePin = { viewModel.togglePin(note) },
                    onDelete = { viewModel.deleteNote(note) },
                    modifier = Modifier.animateItem()
                )
            }
        }
    }
}

/**
 * A note card: a coloured spine on the leading edge (echoing the notebook it
 * belongs to) with the title and a short preview of the body.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun NoteCard(
    note: Note,
    onClick: () -> Unit,
    onTogglePin: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = App2Theme.colors
    val accent = Color(note.accentOr(colors.purple.toArgb()))
    val background by animateColorAsState(colors.surface, label = "noteBg")

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(22.dp))
            .background(background)
            .combinedClickable(onClick = onClick, onLongClick = onDelete)
    ) {
        // Spine: stretches to the row height so it reads like a book edge.
        Box(
            Modifier
                .width(6.dp)
                .fillMaxHeight()
                .background(Brush.verticalGradient(listOf(accent, accent.darken(0.2f))))
        )
        Column(
            Modifier
                .weight(1f)
                .padding(14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (note.notebook != null) {
                    Text(note.notebook.icon, style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.width(6.dp))
                }
                Text(
                    text = note.title.ifBlank { note.body.take(40) },
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
            }
            if (note.body.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    note.body,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        // A single pin conveys the state: faint when off, solid accent when on.
        val pinTint by animateColorAsState(
            targetValue = if (note.pinned) accent else colors.textSecondary.copy(alpha = 0.38f),
            label = "pinTint"
        )
        val pinScale by animateFloatAsState(
            targetValue = if (note.pinned) 1.12f else 1f,
            animationSpec = spring(dampingRatio = 0.45f, stiffness = 700f),
            label = "pinScale"
        )
        Box(
            Modifier
                .size(48.dp)
                .clickable { onTogglePin() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Rounded.PushPin,
                contentDescription = stringResource(
                    if (note.pinned) R.string.note_unpin else R.string.note_pin
                ),
                tint = pinTint,
                modifier = Modifier
                    .size(18.dp)
                    .scale(pinScale)
            )
        }
    }
}

@Composable
private fun Notebook.displayName(): String {
    val res = DefaultNotebooks.labelRes(builtInKey)
    return if (res != null) stringResource(res) else rawName
}

@Composable
private fun Int.localized(): String =
    com.javidstudio.app2.ui.LocalDateFormatter.current.digits(this)


