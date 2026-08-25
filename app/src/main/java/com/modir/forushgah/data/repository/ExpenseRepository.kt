package com.modir.forushgah.data.repository

import androidx.room.withTransaction
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.common.isZero
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.dao.ExpenseCategoryDao
import com.modir.forushgah.data.local.dao.ExpenseDao
import com.modir.forushgah.data.local.dao.ExpenseWithCategory
import com.modir.forushgah.data.local.dao.FinancialTransactionDao
import com.modir.forushgah.data.local.entity.ExpenseCategoryEntity
import com.modir.forushgah.data.local.entity.ExpenseEntity
import com.modir.forushgah.data.local.entity.FinancialTransactionEntity
import com.modir.forushgah.domain.model.Expense
import com.modir.forushgah.domain.model.ExpenseCategory
import com.modir.forushgah.domain.model.ExpenseGroup
import com.modir.forushgah.domain.model.TransactionType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** All inputs for creating/editing an expense (Phase 4.2). */
data class NewExpense(
    val categoryId: Long,
    val amount: Money,
    val date: Long,
    val description: String? = null,
    val orderId: Long? = null,
    val employeeId: Long? = null,
)

/**
 * Phase 4.2: the standalone expense workflow — the SINGLE application-level
 * entry point for creating/modifying/deleting expenses. The UI never touches
 * [ExpenseDao] or [FinancialTransactionDao] directly.
 *
 * Business model:
 * - A bulk purchase (e.g. 5,000,000 Toman of bags and boxes) is a real
 *   business expense: ONE `expenses` row + ONE negative
 *   [TransactionType.EXPENSE] financial event.
 * - It is NOT automatically linked to invoice-level packagingCost. Per-invoice
 *   packaging stays optional (TransactionType.PACKAGING_EXPENSE, Phase 4.1) —
 *   nothing here reads or writes an order's packaging cost, and no bulk
 *   expense is ever distributed across invoices.
 *
 * Financial lifecycle (same append-only model as Phase 4.1):
 * - events are never deleted or mutated;
 * - an EDIT reverses the original event and writes the new one;
 * - a DELETE soft-deletes the row (deletedAt) and reverses its event exactly
 *   once;
 * - every reversal is guarded by `countReversalsOf`, so repeated
 *   edit/delete operations are idempotent no-ops and an event is never
 *   reversed twice.
 */
@Singleton
class ExpenseRepository @Inject constructor(
    private val database: AppDatabase,
    private val expenseDao: ExpenseDao,
    private val expenseCategoryDao: ExpenseCategoryDao,
    private val financialTransactionDao: FinancialTransactionDao,
) {

    companion object {
        /** referenceType marker for standalone-expense financial events. */
        const val EXPENSE_REFERENCE_TYPE = "EXPENSE"
    }

    // ---------- seeding ----------

    /**
     * Built-in expense categories (one per [ExpenseGroup], Persian names).
     * Seeded exactly once: guarded by a stable per-name count check, safe to
     * run on every application start (same pattern as the reference-data
     * seeder).
     */
    suspend fun seedBuiltInCategories() {
        for (group in ExpenseGroup.entries) {
            val name = group.persianName
            if (expenseCategoryDao.countByName(name) == 0) {
                expenseCategoryDao.insert(
                    ExpenseCategoryEntity(name = name, group = group, isBuiltIn = true),
                )
            }
        }
    }

    // ---------- read side ----------

    /** Active (non-deleted) expenses with their category name, newest first. */
    fun observeExpenses(): Flow<List<ExpenseWithCategory>> =
        expenseDao.observeActiveWithCategory()

    fun observeExpensesBetween(start: Long, end: Long): Flow<List<ExpenseWithCategory>> =
        expenseDao.observeActiveBetweenWithCategory(start, end)

    /** Total of active expenses, as Money (Toman). */
    fun observeTotal(): Flow<Money> =
        expenseDao.observeTotalActive().map { Money(it) }

    fun observeCategories(): Flow<List<ExpenseCategory>> =
        expenseCategoryDao.observeAll().map { list -> list.map { it.toDomain() } }

    suspend fun getExpense(id: Long): Expense? =
        expenseDao.getById(id)?.toDomain()

    // ---------- write side ----------

    /**
     * Creates the expense row and its negative EXPENSE financial event in ONE
     * transaction (either both commit or neither does).
     *
     * 5,000,000 Toman packaging purchase → expenses row (5_000_000) +
     * financial event EXPENSE = -5_000_000.
     */
    suspend fun createExpense(
        draft: NewExpense,
        now: Long = System.currentTimeMillis(),
    ): ExpenseEntity = database.withTransaction {
        requireValid(draft)
        val id = expenseDao.insert(
            ExpenseEntity(
                categoryId = draft.categoryId,
                amount = draft.amount,
                date = draft.date,
                description = draft.description,
                orderId = draft.orderId,
                employeeId = draft.employeeId,
            ),
        )
        writeExpenseEvent(id, -draft.amount, draft.date, draft.categoryId, draft.description)
        expenseDao.getById(id)!!
    }

    /**
     * Edits an ACTIVE expense: the old financial effect is reversed exactly
     * once and the new effect is written, atomically. The expense row is
     * updated in place (its id — and therefore the event reference — stays).
     */
    suspend fun updateExpense(
        id: Long,
        draft: NewExpense,
        now: Long = System.currentTimeMillis(),
    ): ExpenseEntity = database.withTransaction {
        val existing = expenseDao.getById(id) ?: error("هزینه‌ای با این شناسه پیدا نشد")
        require(existing.deletedAt == null) { "این هزینه حذف شده است و قابل ویرایش نیست" }
        requireValid(draft)
        reverseActiveEvents(id, now, "ویرایش هزینه")
        expenseDao.update(
            existing.copy(
                categoryId = draft.categoryId,
                amount = draft.amount,
                date = draft.date,
                description = draft.description,
                orderId = draft.orderId,
                employeeId = draft.employeeId,
            ),
        )
        writeExpenseEvent(id, -draft.amount, draft.date, draft.categoryId, draft.description)
        expenseDao.getById(id)!!
    }

    /**
     * SOFT delete: the row and its financial history are preserved, the
     * active financial effect is reversed exactly once, and the expense
     * disappears from the active lists. Repeated deletes are no-ops — no
     * duplicate reversal is ever written.
     */
    suspend fun deleteExpense(id: Long, now: Long = System.currentTimeMillis()) {
        database.withTransaction {
            val existing = expenseDao.getById(id) ?: return@withTransaction
            if (existing.deletedAt != null) return@withTransaction
            reverseActiveEvents(id, now, "حذف هزینه")
            expenseDao.markDeleted(id, now)
        }
    }

    // ---------- validation + financial helpers ----------

    private suspend fun requireValid(draft: NewExpense) {
        require(draft.amount.isPositive) { "مبلغ هزینه باید بیشتر از صفر باشد" }
        require(draft.date > 0) { "تاریخ هزینه معتبر نیست" }
        if (expenseCategoryDao.getById(draft.categoryId) == null) {
            error("دسته‌بندی هزینه معتبر نیست")
        }
    }

    /**
     * Writes the expense's financial event: type EXPENSE, the (signed) amount
     * in Toman, the expense's date and a readable description, plus the
     * (referenceType, referenceId) back-reference to the expense row.
     */
    private suspend fun writeExpenseEvent(
        expenseId: Long,
        amount: Money,
        date: Long,
        categoryId: Long,
        description: String?,
    ) {
        val category = expenseCategoryDao.getById(categoryId)
        val text = description?.trim()?.takeIf { it.isNotEmpty() }
            ?: "هزینه ${category?.name ?: ""}".trim()
        financialTransactionDao.insert(
            FinancialTransactionEntity(
                type = TransactionType.EXPENSE,
                amount = amount,
                date = date,
                referenceType = EXPENSE_REFERENCE_TYPE,
                referenceId = expenseId,
                description = text,
            ),
        )
    }

    /**
     * Reverses every ACTIVE (non-reversal) event of the expense, exactly once
     * per event. Each correction is a NEW EXPENSE event with the negated
     * amount and [FinancialTransactionEntity.reversalOfId] — history is never
     * mutated or deleted. The `countReversalsOf` guard makes repeat calls
     * no-ops, so an already-reversed event is never reversed a second time.
     */
    private suspend fun reverseActiveEvents(expenseId: Long, now: Long, reason: String) {
        for (event in financialTransactionDao.getByReference(EXPENSE_REFERENCE_TYPE, expenseId)) {
            if (event.amount.isZero) continue
            if (event.reversalOfId != null) continue // never reverse a reversal
            if (financialTransactionDao.countReversalsOf(event.id) > 0) continue // already reversed once
            financialTransactionDao.insert(
                FinancialTransactionEntity(
                    type = TransactionType.EXPENSE,
                    amount = -event.amount,
                    date = now,
                    referenceType = EXPENSE_REFERENCE_TYPE,
                    referenceId = expenseId,
                    reversalOfId = event.id,
                    description = "$reason — اصلاح مالی",
                ),
            )
        }
    }
}

private fun ExpenseCategoryEntity.toDomain() = ExpenseCategory(
    id = id,
    name = name,
    group = group,
    isBuiltIn = isBuiltIn,
)

private fun ExpenseEntity.toDomain() = Expense(
    id = id,
    categoryId = categoryId,
    amount = amount,
    date = date,
    description = description,
    orderId = orderId,
    employeeId = employeeId,
    deletedAt = deletedAt,
)
