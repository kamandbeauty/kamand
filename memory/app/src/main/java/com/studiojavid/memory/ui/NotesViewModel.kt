package com.studiojavid.memory.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.studiojavid.memory.data.repo.Note
import com.studiojavid.memory.data.repo.NoteRepository
import com.studiojavid.memory.data.repo.Notebook
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Which shelf/notebook the notes list is currently showing. */
sealed interface NoteFilter {
    data object All : NoteFilter
    data object Loose : NoteFilter
    data class InNotebook(val notebookId: Long) : NoteFilter
}

@OptIn(ExperimentalCoroutinesApi::class)
class NotesViewModel(private val repository: NoteRepository) : ViewModel() {

    private val _filter = MutableStateFlow<NoteFilter>(NoteFilter.All)
    val filter: StateFlow<NoteFilter> = _filter.asStateFlow()

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    /** Last deleted note, kept in memory so the snackbar can undo it. */
    private val _lastDeleted = MutableStateFlow<Note?>(null)
    val lastDeleted: StateFlow<Note?> = _lastDeleted.asStateFlow()

    val notebooks: StateFlow<List<Notebook>> = repository.notebooks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /**
     * Filtering and search are applied over the full list rather than with
     * per-filter queries: the data set is small, and this keeps one source of
     * truth for both the shelf counts and the visible cards.
     */
    val notes: StateFlow<List<Note>> =
        combine(repository.notes, _filter, _query) { all, filter, query ->
            val q = query.trim()
            all.asSequence()
                .filter { note ->
                    when (filter) {
                        NoteFilter.All -> true
                        NoteFilter.Loose -> note.notebook == null
                        is NoteFilter.InNotebook -> note.notebook?.id == filter.notebookId
                    }
                }
                .filter { note ->
                    q.isEmpty() ||
                        note.title.contains(q, ignoreCase = true) ||
                        note.body.contains(q, ignoreCase = true) ||
                        note.notebook?.rawName?.contains(q, ignoreCase = true) == true
                }
                .toList()
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun setFilter(value: NoteFilter) { _filter.value = value }

    fun setQuery(value: String) { _query.value = value }

    fun saveNote(
        id: Long,
        title: String,
        body: String,
        notebookId: Long?,
        color: Int,
        pinned: Boolean
    ) = viewModelScope.launch {
        if (title.isBlank() && body.isBlank()) return@launch
        repository.saveNote(id, title, body, notebookId, color, pinned)
    }

    fun togglePin(note: Note) = viewModelScope.launch {
        repository.setPinned(note.id, !note.pinned)
    }

    fun deleteNote(note: Note) = viewModelScope.launch {
        _lastDeleted.value = note
        repository.deleteNote(note.id)
    }

    fun undoDelete() = viewModelScope.launch {
        _lastDeleted.value?.let { repository.restoreNote(it) }
        _lastDeleted.value = null
    }

    fun clearLastDeleted() { _lastDeleted.value = null }

    fun addNotebook(name: String, icon: String, color: Int) = viewModelScope.launch {
        repository.addNotebook(name, icon, color)
    }

    fun updateNotebook(notebook: Notebook, name: String, icon: String, color: Int) =
        viewModelScope.launch { repository.updateNotebook(notebook, name, icon, color) }

    fun deleteNotebook(notebook: Notebook) = viewModelScope.launch {
        if (_filter.value == NoteFilter.InNotebook(notebook.id)) _filter.value = NoteFilter.All
        repository.deleteNotebook(notebook)
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer { NotesViewModel(app().noteRepository) }
        }
    }
}
