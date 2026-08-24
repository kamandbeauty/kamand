package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.ExpenseCategoryEntity
import com.modir.forushgah.data.local.entity.ExpenseEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ExpenseDao {
    @Insert
    suspend fun insert(expense: ExpenseEntity): Long

    @Query("SELECT * FROM expenses ORDER BY date DESC")
    fun observeAll(): Flow<List<ExpenseEntity>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date BETWEEN :start AND :end")
    fun observeTotalBetween(start: Long, end: Long): Flow<Long>
}

@Dao
interface ExpenseCategoryDao {
    @Insert
    suspend fun insert(category: ExpenseCategoryEntity): Long

    @Query("SELECT * FROM expense_categories ORDER BY name ASC")
    fun observeAll(): Flow<List<ExpenseCategoryEntity>>
}
