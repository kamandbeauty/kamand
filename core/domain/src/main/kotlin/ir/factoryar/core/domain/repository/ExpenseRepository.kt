package ir.factoryar.core.domain.repository

import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ExpenseByCategory
import ir.factoryar.core.domain.model.ExpenseCategory
import ir.factoryar.core.domain.model.ExpenseWithCategory
import ir.factoryar.core.domain.model.ProfitReport
import kotlinx.coroutines.flow.Flow

interface ExpenseRepository {

    fun observeExpenses(
        from: Long? = null,
        to: Long? = null,
        categoryId: Long? = null,
        query: String = "",
    ): Flow<List<ExpenseWithCategory>>

    suspend fun getExpense(id: Long): Expense?
    suspend fun saveExpense(expense: Expense): Long
    suspend fun deleteExpense(id: Long)

    /** جمع هزینه‌ها در بازه */
    suspend fun totalInRange(from: Long, to: Long): Long
    fun observeTotalInRange(from: Long, to: Long): Flow<Long>
    suspend fun byCategoryInRange(from: Long, to: Long): List<ExpenseByCategory>

    // ---------------- دسته‌بندی هزینه ----------------
    fun observeCategories(): Flow<List<ExpenseCategory>>
    suspend fun saveCategory(category: ExpenseCategory): Long
    suspend fun deleteCategory(id: Long)
    /** ساخت دسته‌های پیش‌فرض در اولین اجرا */
    suspend fun ensureDefaultCategories()
}

/** گزارش سود و زیان (ترکیب فروش، بهای تمام‌شده و هزینه‌ها) */
interface ProfitRepository {
    suspend fun buildProfitReport(from: Long, to: Long): ProfitReport
}
