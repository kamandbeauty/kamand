package com.studiojavid.memory.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

/** Whether a given day has a page, for the calendar dots. */
data class DayMark(val date: Long, val mood: Int, val hasPhoto: Int)

@Dao
interface MemoryDao {

    @Query("SELECT * FROM memories ORDER BY date DESC")
    fun observeAll(): Flow<List<MemoryEntity>>

    @Query("SELECT * FROM memories WHERE favorite = 1 ORDER BY date DESC")
    fun observeFavorites(): Flow<List<MemoryEntity>>

    @Query("SELECT * FROM memories WHERE date = :epochDay")
    fun observeByDate(epochDay: Long): Flow<MemoryEntity?>

    @Query("SELECT * FROM memories WHERE date = :epochDay")
    suspend fun findByDate(epochDay: Long): MemoryEntity?

    @Query("SELECT * FROM memories WHERE id = :id")
    suspend fun findById(id: Long): MemoryEntity?

    @Query("SELECT * FROM memories WHERE date BETWEEN :from AND :to ORDER BY date DESC")
    fun observeBetween(from: Long, to: Long): Flow<List<MemoryEntity>>

    /**
     * Pages of a date range reduced to what the calendar grid needs, so the
     * month view never has to load photo paths and bodies it will not draw.
     */
    @Query(
        """
        SELECT date AS date, mood AS mood,
               (CASE WHEN photoUri <> '' THEN 1 ELSE 0 END) AS hasPhoto
        FROM memories WHERE date BETWEEN :from AND :to
        """
    )
    fun observeDayMarks(from: Long, to: Long): Flow<List<DayMark>>

    /**
     * Same day and month in earlier years — the "on this day" look-back.
     * The Jalali month/day cannot be derived in SQL, so the caller passes the
     * candidate epoch days it computed with the Jalali engine.
     */
    @Query("SELECT * FROM memories WHERE date IN (:epochDays) ORDER BY date DESC")
    fun observeOnDays(epochDays: List<Long>): Flow<List<MemoryEntity>>

    @Query("SELECT COUNT(*) FROM memories")
    fun observeCount(): Flow<Int>

    @Query("SELECT DISTINCT date FROM memories ORDER BY date DESC")
    fun observeWrittenDays(): Flow<List<Long>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(memory: MemoryEntity): Long

    @Update
    suspend fun update(memory: MemoryEntity)

    @Query("DELETE FROM memories WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM memories")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(memories: List<MemoryEntity>)
}
