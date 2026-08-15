package com.roozi.app.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

data class DayCount(val dueDate: Long, val total: Int, val done: Int)

@Dao
interface TaskDao {

    @Query("SELECT * FROM tasks ORDER BY isCompleted ASC, sortOrder ASC, dueTime IS NULL, dueTime ASC, createdAt DESC")
    fun observeAll(): Flow<List<TaskEntity>>

    @Query(
        """
        SELECT * FROM tasks
        WHERE dueDate = :epochDay
        ORDER BY isCompleted ASC, sortOrder ASC, dueTime IS NULL, dueTime ASC, createdAt DESC
        """
    )
    fun observeByDate(epochDay: Long): Flow<List<TaskEntity>>

    /** Tasks for today plus any unfinished task from an earlier day (carried over). */
    @Query(
        """
        SELECT * FROM tasks
        WHERE dueDate = :epochDay
           OR (dueDate IS NOT NULL AND dueDate < :epochDay AND isCompleted = 0)
           OR (dueDate IS NULL AND isCompleted = 0)
        ORDER BY isCompleted ASC, sortOrder ASC, dueTime IS NULL, dueTime ASC, createdAt DESC
        """
    )
    fun observeTodayAgenda(epochDay: Long): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE isCompleted = 1 ORDER BY completedAt DESC")
    fun observeCompleted(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :id")
    suspend fun findById(id: Long): TaskEntity?

    @Query(
        """
        SELECT dueDate AS dueDate, COUNT(*) AS total, SUM(isCompleted) AS done
        FROM tasks WHERE dueDate BETWEEN :from AND :to GROUP BY dueDate
        """
    )
    fun observeDayCounts(from: Long, to: Long): Flow<List<DayCount>>

    @Query("SELECT * FROM tasks WHERE reminderEnabled = 1 AND isCompleted = 0 AND reminderTime IS NOT NULL")
    suspend fun pendingReminders(): List<TaskEntity>

    @Query("SELECT COUNT(*) FROM tasks WHERE isCompleted = 1")
    fun observeCompletedCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM tasks WHERE isCompleted = 0")
    fun observePendingCount(): Flow<Int>

    /** Distinct epoch days on which at least one task was completed (for the streak). */
    @Query("SELECT DISTINCT completedAt FROM tasks WHERE isCompleted = 1 AND completedAt IS NOT NULL ORDER BY completedAt DESC")
    fun observeCompletionTimes(): Flow<List<Long>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(task: TaskEntity): Long

    @Update
    suspend fun update(task: TaskEntity)

    @Delete
    suspend fun delete(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM tasks WHERE isCompleted = 1")
    suspend fun deleteCompleted()

    @Query("DELETE FROM tasks")
    suspend fun clear()

    @Query("SELECT IFNULL(MAX(sortOrder), 0) + 1 FROM tasks")
    suspend fun nextSortOrder(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(tasks: List<TaskEntity>)
}

@Dao
interface CategoryDao {

    @Query("SELECT * FROM categories ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<CategoryEntity>>

    @Query("SELECT COUNT(*) FROM categories")
    suspend fun count(): Int

    @Upsert
    suspend fun upsert(category: CategoryEntity): Long

    @Delete
    suspend fun delete(category: CategoryEntity)

    @Query("DELETE FROM categories")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(categories: List<CategoryEntity>)

    @Transaction
    suspend fun replaceAll(categories: List<CategoryEntity>) {
        clear()
        insertAll(categories)
    }
}
