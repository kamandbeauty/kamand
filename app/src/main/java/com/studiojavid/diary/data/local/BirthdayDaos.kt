package com.studiojavid.diary.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface BirthdayDao {

    @Query("SELECT * FROM birthday_people ORDER BY name ASC")
    fun observeAll(): Flow<List<BirthdayPersonEntity>>

    @Query("SELECT * FROM birthday_people WHERE id = :id")
    fun observePerson(id: Long): Flow<BirthdayPersonEntity?>

    @Query("SELECT * FROM birthday_people WHERE id = :id")
    suspend fun findById(id: Long): BirthdayPersonEntity?

    /** Everyone born on a given Jalali day, for the calendar view. */
    @Query("SELECT * FROM birthday_people WHERE birthMonth = :month AND birthDay = :day ORDER BY name ASC")
    fun observeOnDay(month: Int, day: Int): Flow<List<BirthdayPersonEntity>>

    @Query("SELECT * FROM birthday_people WHERE reminderEnabled = 1")
    suspend fun withReminders(): List<BirthdayPersonEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(person: BirthdayPersonEntity): Long

    @Update
    suspend fun update(person: BirthdayPersonEntity)

    @Query("DELETE FROM birthday_people WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM birthday_people")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(people: List<BirthdayPersonEntity>)
}

@Dao
interface GiftIdeaDao {

    @Query("SELECT * FROM gift_ideas WHERE personId = :personId ORDER BY isCompleted ASC, createdAt DESC")
    fun observeForPerson(personId: Long): Flow<List<GiftIdeaEntity>>

    @Query("SELECT * FROM gift_ideas WHERE id = :id")
    suspend fun findById(id: Long): GiftIdeaEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(idea: GiftIdeaEntity): Long

    @Update
    suspend fun update(idea: GiftIdeaEntity)

    @Delete
    suspend fun delete(idea: GiftIdeaEntity)

    @Query("DELETE FROM gift_ideas WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM gift_ideas")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(ideas: List<GiftIdeaEntity>)
}
