package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Embedded
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.modir.forushgah.data.local.entity.ExpenseCategoryEntity
import com.modir.forushgah.data.local.entity.ExpenseEntity
import kotlinx.coroutines.flow.Flow

/** Expense + its category name in one query — what the expense list renders. */
data class ExpenseWithCategory(
    @Embedded val expense: ExpenseEntity,
    val categoryName: String,
)

@Dao
interface ExpenseDao {
    @Insert
    suspend fun insert(expense: ExpenseEntity): Long

    @Update
    suspend fun update(expense: ExpenseEntity)

    @Query("SELECT * FROM expenses WHERE id = :id")
    suspend fun getById(id: Long): ExpenseEntity?

    /** Every expense row, deleted or not — audit view only. */
    @Query("SELECT * FROM expenses ORDER BY date DESC, id DESC")
    fun observeAll(): Flow<List<ExpenseEntity>>

    /** Active (non-deleted) expenses with the category name, newest first. */
    @Query(
        """
        SELECT e.*, c.name AS categoryName
        FROM expenses e
        JOIN expense_categories c ON c.id = e.categoryId
        WHERE e.deletedAt IS NULL
        ORDER BY e.date DESC, e.id DESC
        """,
    )
    fun observeActiveWithCategory(): Flow<List<ExpenseWithCategory>>

    @Query(
        """
        SELECT e.*, c.name AS categoryName
        FROM expenses e
        JOIN expense_categories c ON c.id = e.categoryId
        WHERE e.deletedAt IS NULL AND e.date BETWEEN :start AND :end
        ORDER BY e.date DESC, e.id DESC
        """,
    )
    fun observeActiveBetweenWithCategory(start: Long, end: Long): Flow<List<ExpenseWithCategory>>

    /** Active total, in Toman (Money is stored as Long via MoneyConverters). */
    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE deletedAt IS NULL")
    fun observeTotalActive(): Flow<Long>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE deletedAt IS NULL AND date BETWEEN :start AND :end")
    fun observeTotalBetween(start: Long, end: Long): Flow<Long>

    /** Phase 4.2: soft delete — the row (and its financial events) is kept. */
    @Query("UPDATE expenses SET deletedAt = :deletedAt WHERE id = :id")
    suspend fun markDeleted(id: Long, deletedAt: Long)
}

@Dao
interface ExpenseCategoryDao {
    @Insert
    suspend fun insert(category: ExpenseCategoryEntity): Long

    @Query("SELECT * FROM expense_categories WHERE id = :id")
    suspend fun getById(id: Long): ExpenseCategoryEntity?

    /** Idempotency guard for built-in seeding (stable name per group). */
    @Query("SELECT COUNT(*) FROM expense_categories WHERE name = :name")
    suspend fun countByName(name: String): Int

    @Query("SELECT * FROM expense_categories ORDER BY name ASC")
    fun observeAll(): Flow<List<ExpenseCategoryEntity>>
}
