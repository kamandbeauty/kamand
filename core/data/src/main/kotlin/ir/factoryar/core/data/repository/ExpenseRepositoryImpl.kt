package ir.factoryar.core.data.repository

import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.database.dao.ExpenseDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.database.entity.ExpenseCategoryEntity
import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ExpenseByCategory
import ir.factoryar.core.domain.model.ExpenseCategory
import ir.factoryar.core.domain.model.ExpenseWithCategory
import ir.factoryar.core.domain.model.ProfitPoint
import ir.factoryar.core.domain.model.ProfitReport
import ir.factoryar.core.domain.repository.ExpenseRepository
import ir.factoryar.core.domain.repository.ProfitRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ExpenseRepositoryImpl @Inject constructor(
    private val expenseDao: ExpenseDao,
    private val invoiceDao: InvoiceDao,
) : ExpenseRepository, ProfitRepository {

    override fun observeExpenses(
        from: Long?,
        to: Long?,
        categoryId: Long?,
        query: String,
    ): Flow<List<ExpenseWithCategory>> {
        val source = if (from != null && to != null) {
            expenseDao.observeInRange(from, to)
        } else {
            expenseDao.observeAll()
        }
        return combine(source, expenseDao.observeCategories()) { expenses, categories ->
            val byId = categories.associateBy { it.id }
            expenses.asSequence()
                .map { it.toDomain() }
                .filter { categoryId == null || it.categoryId == categoryId }
                .filter { e ->
                    query.isBlank() ||
                        e.title.contains(query, ignoreCase = true) ||
                        e.note.contains(query, ignoreCase = true)
                }
                .map { e ->
                    val cat = e.categoryId?.let(byId::get)
                    ExpenseWithCategory(e, cat?.name, cat?.colorArgb ?: 0xFF9E9E9E)
                }
                .toList()
        }
    }

    override suspend fun getExpense(id: Long): Expense? = expenseDao.getById(id)?.toDomain()

    override suspend fun saveExpense(expense: Expense): Long {
        val now = DateUtils.now()
        val prepared = expense.copy(
            date = if (expense.date == 0L) now else expense.date,
            createdAt = if (expense.id == 0L) now else expense.createdAt,
        )
        val id = expenseDao.upsert(prepared.toEntity())
        return if (expense.id == 0L) id else expense.id
    }

    override suspend fun deleteExpense(id: Long) = expenseDao.deleteById(id)

    override suspend fun totalInRange(from: Long, to: Long): Long = expenseDao.sumInRange(from, to)

    override fun observeTotalInRange(from: Long, to: Long): Flow<Long> =
        expenseDao.observeSumInRange(from, to)

    override suspend fun byCategoryInRange(from: Long, to: Long): List<ExpenseByCategory> =
        expenseDao.totalsByCategory(from, to).map { row ->
            ExpenseByCategory(
                categoryId = row.categoryId,
                categoryName = row.categoryName ?: "بدون دسته",
                total = row.total,
                count = row.count,
            )
        }

    override fun observeCategories(): Flow<List<ExpenseCategory>> =
        expenseDao.observeCategories().map { list -> list.map { it.toDomain() } }

    override suspend fun saveCategory(category: ExpenseCategory): Long =
        expenseDao.upsertCategory(category.toEntity())

    override suspend fun deleteCategory(id: Long) = expenseDao.deleteCategory(id)

    override suspend fun ensureDefaultCategories() {
        if (expenseDao.categoryCount() > 0) return
        ExpenseCategory.DEFAULTS.forEachIndexed { index, (name, color) ->
            expenseDao.upsertCategory(
                ExpenseCategoryEntity(
                    name = name,
                    colorArgb = color,
                    isDefault = true,
                    sortOrder = index,
                ),
            )
        }
    }

    // ---------------- گزارش سود و زیان ----------------

    override suspend fun buildProfitReport(from: Long, to: Long): ProfitReport {
        val revenue = invoiceDao.getInRange(from, to)
            .filter { it.type == "SALE" }
            .sumOf { it.grandTotal }
        val cogs = invoiceDao.sumCogs(from, to)
        val expensesTotal = expenseDao.sumInRange(from, to)
        val byCategory = byCategoryInRange(from, to)

        // انتخاب اندازه سطل: تا ۴۵ روز روزانه، بیشتر از آن ماهانه
        val spanDays = ((to - from) / DateUtils.DAY_MILLIS).toInt().coerceAtLeast(1)
        val series = if (spanDays <= 45) {
            buildDailySeries(from, to)
        } else {
            buildMonthlySeries(from, to)
        }

        return ProfitReport(
            from = from,
            to = to,
            revenue = revenue,
            costOfGoodsSold = cogs,
            operatingExpenses = expensesTotal,
            expensesByCategory = byCategory,
            series = series,
        )
    }

    private suspend fun buildDailySeries(from: Long, to: Long): List<ProfitPoint> {
        val day = DateUtils.DAY_MILLIS
        val revenueRows = invoiceDao.revenueAndCostBuckets(from, to, day).associateBy { it.bucket }
        val expenseRows = expenseDao.getInRange(from, to)
            .groupBy { (it.date / day) * day }
            .mapValues { (_, list) -> list.sumOf { it.amount } }

        val start = (from / day) * day
        val points = mutableListOf<ProfitPoint>()
        var bucket = start
        while (bucket < to) {
            val jalali = JalaliConverter.fromEpochMillis(bucket)
            val row = revenueRows[bucket]
            points += ProfitPoint(
                bucketStart = bucket,
                label = "${jalali.day}/${jalali.month}",
                revenue = row?.revenue ?: 0L,
                cost = row?.cost ?: 0L,
                expenses = expenseRows[bucket] ?: 0L,
            )
            bucket += day
        }
        return points
    }

    private suspend fun buildMonthlySeries(from: Long, to: Long): List<ProfitPoint> {
        val startJalali = JalaliConverter.fromEpochMillis(from)
        val endJalali = JalaliConverter.fromEpochMillis(to)
        val points = mutableListOf<ProfitPoint>()

        var year = startJalali.year
        var month = startJalali.month
        while (year < endJalali.year || (year == endJalali.year && month <= endJalali.month)) {
            val monthStart = JalaliConverter.toEpochMillis(JalaliDate(year, month, 1))
            val nextMonthYear = if (month == 12) year + 1 else year
            val nextMonth = if (month == 12) 1 else month + 1
            val monthEnd = JalaliConverter.toEpochMillis(JalaliDate(nextMonthYear, nextMonth, 1))

            val rangeStart = maxOf(monthStart, from)
            val rangeEnd = minOf(monthEnd, to)
            if (rangeEnd > rangeStart) {
                val rows = invoiceDao.revenueAndCostBuckets(rangeStart, rangeEnd, DateUtils.DAY_MILLIS)
                points += ProfitPoint(
                    bucketStart = monthStart,
                    label = JalaliDate.monthName(month).take(4),
                    revenue = rows.sumOf { it.revenue },
                    cost = rows.sumOf { it.cost },
                    expenses = expenseDao.sumInRange(rangeStart, rangeEnd),
                )
            }
            year = nextMonthYear
            month = nextMonth
        }
        return points
    }
}
