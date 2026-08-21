package com.studiojavid.diary.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

/** Number of notes filed in a notebook, used for the shelf. */
data class NotebookCount(val notebookId: Long, val total: Int)

@Dao
interface NoteDao {

    @Query("SELECT * FROM notes ORDER BY pinned DESC, updatedAt DESC")
    fun observeAll(): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE notebookId = :notebookId ORDER BY pinned DESC, updatedAt DESC")
    fun observeInNotebook(notebookId: Long): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE notebookId IS NULL ORDER BY pinned DESC, updatedAt DESC")
    fun observeLoose(): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE id = :id")
    suspend fun findById(id: Long): NoteEntity?

    @Query(
        """
        SELECT notebookId AS notebookId, COUNT(*) AS total
        FROM notes WHERE notebookId IS NOT NULL GROUP BY notebookId
        """
    )
    fun observeNotebookCounts(): Flow<List<NotebookCount>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(note: NoteEntity): Long

    @Update
    suspend fun update(note: NoteEntity)

    @Query("DELETE FROM notes WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM notes")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(notes: List<NoteEntity>)

    /** Loose the notes of a notebook rather than deleting them with it. */
    @Query("UPDATE notes SET notebookId = NULL WHERE notebookId = :notebookId")
    suspend fun detachFromNotebook(notebookId: Long)
}

@Dao
interface NotebookDao {

    @Query("SELECT * FROM notebooks ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<NotebookEntity>>

    @Query("SELECT COUNT(*) FROM notebooks")
    suspend fun count(): Int

    @Upsert
    suspend fun upsert(notebook: NotebookEntity): Long

    @Delete
    suspend fun delete(notebook: NotebookEntity)

    @Query("DELETE FROM notebooks")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(notebooks: List<NotebookEntity>)
}
