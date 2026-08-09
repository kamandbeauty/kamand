package ir.factoryar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import ir.factoryar.core.database.entity.ExpenseCategoryEntity
import ir.factoryar.core.database.entity.ExpenseCategoryTotalRow
import ir.factoryar.core.database.entity.ExpenseEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ExpenseDao {

    @Query("SELECT * FROM expenses ORDER BY date DESC, id DESC")
    fun observeAll(): Flow<List<ExpenseEntity>>

    @Query("SELECT * FROM expenses WHERE date >= :from AND date < :to ORDER BY date DESC, id DESC")
    fun observeInRange(from: Long, to: Long): Flow<List<ExpenseEntity>>

    @Query("SELECT * FROM expenses WHERE id = :id")
    suspend fun getById(id: Long): ExpenseEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(expense: ExpenseEntity): Long

    @Query("DELETE FROM expenses WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date >= :from AND date < :to")
    suspend fun sumInRange(from: Long, to: Long): Long

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date >= :from AND date < :to")
    fun observeSumInRange(from: Long, to: Long): Flow<Long>

    @Query(
        """
        SELECT e.categoryId AS categoryId,
               c.name AS categoryName,
               COALESCE(SUM(e.amount), 0) AS total,
               COUNT(e.id) AS count
        FROM expenses e
        LEFT JOIN expense_categories c ON c.id = e.categoryId
        WHERE e.date >= :from AND e.date < :to
        GROUP BY e.categoryId
        ORDER BY total DESC
        """
    )
    suspend fun totalsByCategory(from: Long, to: Long): List<ExpenseCategoryTotalRow>

    @Query("SELECT * FROM expenses WHERE date >= :from AND date < :to")
    suspend fun getInRange(from: Long, to: Long): List<ExpenseEntity>

    // ---------------- دسته‌بندی ----------------

    @Query("SELECT * FROM expense_categories ORDER BY sortOrder ASC, name COLLATE NOCASE ASC")
    fun observeCategories(): Flow<List<ExpenseCategoryEntity>>

    @Query("SELECT COUNT(*) FROM expense_categories")
    suspend fun categoryCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertCategory(category: ExpenseCategoryEntity): Long

    @Query("DELETE FROM expense_categories WHERE id = :id AND isDefault = 0")
    suspend fun deleteCategory(id: Long)
}
