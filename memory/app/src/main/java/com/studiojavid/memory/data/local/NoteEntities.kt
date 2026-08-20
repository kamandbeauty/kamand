package com.studiojavid.memory.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A notebook — the "book" a set of notes lives in.
 *
 * Kept separate from task categories on purpose: notes and tasks are organised
 * differently in practice, and merging them would force one vocabulary onto
 * both. A notebook carries its own cover colour and emoji so the shelf reads
 * like a row of real books.
 */
@Entity(
    tableName = "notebooks",
    indices = [Index(value = ["name"], unique = true)]
)
data class NotebookEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** Emoji shown on the spine/cover. */
    val icon: String,
    /** ARGB cover colour. */
    val color: Int,
    /** Resource key for built-in notebooks so they can be localized. */
    @ColumnInfo(defaultValue = "") val builtInKey: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "notes",
    foreignKeys = [
        ForeignKey(
            entity = NotebookEntity::class,
            parentColumns = ["id"],
            childColumns = ["notebookId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [Index("notebookId"), Index("updatedAt")]
)
data class NoteEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val body: String = "",
    /** Null means the note is loose — not filed in any notebook. */
    val notebookId: Long? = null,
    /** ARGB accent for the note card; 0 means "inherit from the notebook". */
    @ColumnInfo(defaultValue = "0") val color: Int = 0,
    val pinned: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
