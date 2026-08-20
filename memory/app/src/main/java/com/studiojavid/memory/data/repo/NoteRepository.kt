package com.studiojavid.memory.data.repo

import android.content.Context
import androidx.compose.runtime.Immutable
import com.studiojavid.memory.R
import com.studiojavid.memory.data.local.NoteEntity
import com.studiojavid.memory.data.local.NotebookEntity
import com.studiojavid.memory.data.local.MemoryDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first

/** UI-facing notebook. Built-in ones resolve their label from resources. */
@Immutable
data class Notebook(
    val id: Long,
    val rawName: String,
    val icon: String,
    val color: Int,
    val builtInKey: String,
    val noteCount: Int = 0
) {
    val isBuiltIn: Boolean get() = builtInKey.isNotEmpty()
}

@Immutable
data class Note(
    val id: Long,
    val title: String,
    val body: String,
    val notebook: Notebook?,
    val color: Int,
    val pinned: Boolean,
    val createdAt: Long,
    val updatedAt: Long
) {
    /** Falls back to the notebook's cover colour when the note has none. */
    fun accentOr(fallback: Int): Int = when {
        color != 0 -> color
        notebook != null -> notebook.color
        else -> fallback
    }
}

/** Built-in notebooks, mirroring how DefaultCategories seeds task categories. */
object DefaultNotebooks {

    const val PERSONAL = "personal"
    const val IDEAS = "ideas"
    const val WORK = "work"

    private const val PURPLE = 0xFF7C5CFF.toInt()
    private const val YELLOW = 0xFFFFC93C.toInt()
    private const val BLUE = 0xFF4C8DF6.toInt()
    private const val CORAL = 0xFFFF6B6B.toInt()
    private const val MINT = 0xFF2ECC9B.toInt()
    private const val PINK = 0xFFFF7EB6.toInt()
    private const val ORANGE = 0xFFFF9F45.toInt()
    private const val TURQUOISE = 0xFF31C8E6.toInt()

    fun seed(): List<NotebookEntity> = listOf(
        NotebookEntity(name = "شخصی", icon = "📔", color = PURPLE, builtInKey = PERSONAL, createdAt = 1),
        NotebookEntity(name = "ایده‌ها", icon = "💡", color = YELLOW, builtInKey = IDEAS, createdAt = 2),
        NotebookEntity(name = "کار", icon = "📘", color = BLUE, builtInKey = WORK, createdAt = 3)
    )

    fun labelRes(key: String): Int? = when (key) {
        PERSONAL -> R.string.notebook_personal
        IDEAS -> R.string.notebook_ideas
        WORK -> R.string.notebook_work
        else -> null
    }

    val palette: List<Int> = listOf(PURPLE, BLUE, MINT, TURQUOISE, YELLOW, ORANGE, CORAL, PINK)

    val covers: List<String> = listOf("📔", "📘", "📗", "📙", "📕", "📓", "💡", "✍️", "🎒", "🌱")
}

/**
 * Notes and notebooks. Mirrors [TaskRepository] in shape so the two feature
 * areas stay consistent, but is intentionally a separate class: notes have no
 * reminders, recurrence or widget coupling.
 */
class NoteRepository(
    context: Context,
    db: MemoryDatabase = MemoryDatabase.get(context)
) {
    private val noteDao = db.noteDao()
    private val notebookDao = db.notebookDao()

    val notebooks: Flow<List<Notebook>> =
        notebookDao.observeAll().combine(noteDao.observeNotebookCounts()) { books, counts ->
            val byId = counts.associate { it.notebookId to it.total }
            books.map { it.toDomain(byId[it.id] ?: 0) }
        }

    val notes: Flow<List<Note>> = noteDao.observeAll().withNotebooks()

    fun notesIn(notebookId: Long): Flow<List<Note>> =
        noteDao.observeInNotebook(notebookId).withNotebooks()

    val looseNotes: Flow<List<Note>> = noteDao.observeLoose().withNotebooks()

    private fun Flow<List<NoteEntity>>.withNotebooks(): Flow<List<Note>> =
        combine(notebooks) { entities, books ->
            val byId = books.associateBy { it.id }
            entities.map { it.toDomain(byId[it.notebookId]) }
        }

    suspend fun ensureSeeded() {
        if (notebookDao.count() == 0) notebookDao.insertAll(DefaultNotebooks.seed())
    }

    suspend fun saveNote(
        id: Long = 0,
        title: String,
        body: String,
        notebookId: Long?,
        color: Int = 0,
        pinned: Boolean = false
    ): Long {
        val existing = if (id != 0L) noteDao.findById(id) else null
        val now = System.currentTimeMillis()
        val entity = NoteEntity(
            id = id,
            title = title.trim(),
            body = body.trim(),
            notebookId = notebookId,
            color = color,
            pinned = pinned,
            createdAt = existing?.createdAt ?: now,
            updatedAt = now
        )
        return if (id == 0L) noteDao.insert(entity) else {
            noteDao.update(entity); id
        }
    }

    suspend fun setPinned(noteId: Long, pinned: Boolean) {
        val note = noteDao.findById(noteId) ?: return
        noteDao.update(note.copy(pinned = pinned, updatedAt = System.currentTimeMillis()))
    }

    suspend fun deleteNote(noteId: Long) = noteDao.deleteById(noteId)

    /** Restores a deleted note (undo), keeping its original id. */
    suspend fun restoreNote(note: Note) {
        noteDao.insert(
            NoteEntity(
                id = note.id,
                title = note.title,
                body = note.body,
                notebookId = note.notebook?.id,
                color = note.color,
                pinned = note.pinned,
                createdAt = note.createdAt,
                updatedAt = note.updatedAt
            )
        )
    }

    suspend fun addNotebook(name: String, icon: String, color: Int): Long =
        notebookDao.upsert(NotebookEntity(name = name.trim(), icon = icon, color = color))

    suspend fun updateNotebook(notebook: Notebook, name: String, icon: String, color: Int) {
        notebookDao.upsert(
            NotebookEntity(
                id = notebook.id,
                name = name.trim(),
                icon = icon,
                color = color,
                builtInKey = notebook.builtInKey
            )
        )
    }

    /** Deleting a notebook keeps its notes; they simply become loose. */
    suspend fun deleteNotebook(notebook: Notebook) {
        noteDao.detachFromNotebook(notebook.id)
        notebookDao.delete(
            NotebookEntity(
                id = notebook.id,
                name = notebook.rawName,
                icon = notebook.icon,
                color = notebook.color,
                builtInKey = notebook.builtInKey
            )
        )
    }

    // Backup support -------------------------------------------------------

    suspend fun snapshot(): Pair<List<NoteEntity>, List<NotebookEntity>> {
        val notes = noteDao.observeAll().first()
        val books = notebookDao.observeAll().first()
        return notes to books
    }

    suspend fun replaceAll(notes: List<NoteEntity>, notebooks: List<NotebookEntity>) {
        noteDao.clear()
        notebookDao.clear()
        notebookDao.insertAll(notebooks)
        noteDao.insertAll(notes)
    }
}

private fun NotebookEntity.toDomain(count: Int) =
    Notebook(id, name, icon, color, builtInKey, count)

private fun NoteEntity.toDomain(notebook: Notebook?) =
    Note(id, title, body, notebook, color, pinned, createdAt, updatedAt)
