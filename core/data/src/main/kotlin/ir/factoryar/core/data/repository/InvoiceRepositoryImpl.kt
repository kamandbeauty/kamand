package ir.factoryar.core.data.repository

import androidx.room.withTransaction
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.database.FactorYarDatabase
import ir.factoryar.core.database.dao.CustomerDao
import ir.factoryar.core.database.dao.ExpenseDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.database.dao.ProductDao
import ir.factoryar.core.database.entity.StockMovementEntity
import ir.factoryar.core.domain.model.CustomerBalanceRow
import ir.factoryar.core.domain.model.DashboardSummary
import ir.factoryar.core.domain.model.InvoiceCalculator
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InventorySummary
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.model.SalesReport
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InvoiceRepositoryImpl @Inject constructor(
    private val db: FactorYarDatabase,
    private val invoiceDao: InvoiceDao,
    private val customerDao: CustomerDao,
    private val productDao: ProductDao,
    private val expenseDao: ExpenseDao,
    private val settingsRepository: SettingsRepository,
) : InvoiceRepository {

    override fun observeInvoices(
        type: InvoiceType?,
        status: PaymentStatus?,
        query: String,
        overdueOnly: Boolean,
    ): Flow<List<InvoiceWithDetails>> =
        combine(invoiceDao.observeAll(), customerDao.observeAll()) { invoices, customers ->
            val customerMap = customers.associate { it.id to it.toDomain() }
            val now = DateUtils.now()
            invoices.asSequence()
                .map { it.toDomain() }
                .filter { type == null || it.type == type }
                .filter { status == null || it.status == status }
                .filter { !overdueOnly || it.isOverdue }
                .filter { inv ->
                    query.isBlank() ||
                        inv.number.contains(query, ignoreCase = true) ||
                        (inv.customerId?.let { customerMap[it]?.name }?.contains(query) == true)
                }
                .map { inv -> InvoiceWithDetails(inv, emptyList(), inv.customerId?.let(customerMap::get)) }
                .sortedByDescending { it.invoice.issueDate }
                .toList()
        }

    override fun observeInvoice(id: Long): Flow<InvoiceWithDetails?> =
        combine(invoiceDao.observeWithItems(id), customerDao.observeAll()) { withItems, customers ->
            withItems ?: return@combine null
            val customer = withItems.invoice.customerId?.let { cid -> customers.firstOrNull { it.id == cid } }
            withItems.toDomain(customer?.toDomain())
        }

    override suspend fun getInvoice(id: Long): InvoiceWithDetails? =
        observeInvoice(id).first()

    override suspend fun previewNextNumber(type: InvoiceType): String =
        settingsRepository.previewNextNumber(type)

    override suspend fun saveInvoice(details: InvoiceWithDetails): Long {
        val now = DateUtils.now()
        val totals = InvoiceCalculator.calculate(details.items, details.invoice.globalDiscount)
        val isNew = details.invoice.id == 0L
        return db.withTransaction {
            val number = if (isNew && details.invoice.number.isBlank()) {
                generateUniqueNumber(details.invoice.type)
            } else {
                details.invoice.number
            }
            val status = details.invoice.status
            val invoice = details.invoice.copy(
                number = number,
                subtotal = totals.subtotal,
                discountTotal = totals.discountTotal,
                taxTotal = totals.taxTotal,
                grandTotal = totals.grandTotal,
                paidAmount = if (status == PaymentStatus.PAID) totals.grandTotal else details.invoice.paidAmount,
                createdAt = if (isNew) now else details.invoice.createdAt,
                updatedAt = now,
            )
            val invoiceId = invoiceDao.upsertInvoice(invoice.toEntity())
            val realId = if (isNew || invoiceId == 0L) invoiceId else details.invoice.id

            // برگرداندن اثر انبارِ نسخه قبلی (در حالت ویرایش) پیش از اعمال نسخه جدید
            if (!isNew) productDao.revertInvoiceEffect(realId, now)

            // snapshot بهای تمام‌شده از انبار برای محاسبه سود
            val itemsWithCost = details.items.mapIndexed { index, item ->
                val cost = if (item.costPrice > 0) {
                    item.costPrice
                } else {
                    item.productId?.let { productDao.getById(it)?.costPrice } ?: 0L
                }
                item.copy(id = 0, invoiceId = realId, sortOrder = index, costPrice = cost)
            }

            // بازنویسی آیتم‌ها
            invoiceDao.deleteItemsOf(realId)
            invoiceDao.upsertItems(itemsWithCost.map { it.toEntity() })

            // همگام‌سازی خودکار موجودی انبار
            applyStockEffect(realId, invoice.type, itemsWithCost, now)

            realId
        }
    }

    /**
     * کسر خودکار موجودی برای فاکتور فروش و افزایش آن برای فاکتور خرید.
     * پیش‌فاکتور روی انبار اثری ندارد.
     */
    private suspend fun applyStockEffect(
        invoiceId: Long,
        type: InvoiceType,
        items: List<ir.factoryar.core.domain.model.InvoiceItem>,
        now: Long,
    ) {
        val sign = when (type) {
            InvoiceType.SALE -> -1.0
            InvoiceType.PURCHASE -> 1.0
            InvoiceType.PROFORMA -> return // پیش‌فاکتور موجودی را تغییر نمی‌دهد
        }
        val reason = if (type == InvoiceType.SALE) StockMoveReason.SALE else StockMoveReason.PURCHASE
        items.forEach { item ->
            val productId = item.productId ?: return@forEach
            val product = productDao.getById(productId) ?: return@forEach
            if (product.isService) return@forEach
            val delta = sign * item.quantity
            if (delta == 0.0) return@forEach
            productDao.applyStockDelta(productId, delta, now)
            productDao.insertMovement(
                StockMovementEntity(
                    productId = productId,
                    quantityDelta = delta,
                    reason = reason.name,
                    invoiceId = invoiceId,
                    note = item.title,
                    createdAt = now,
                ),
            )
            // فاکتور خرید بهای تمام‌شده کالا را به‌روز می‌کند
            if (type == InvoiceType.PURCHASE && item.unitPrice > 0) {
                productDao.upsert(product.copy(costPrice = item.unitPrice, updatedAt = now))
            }
        }
    }

    private suspend fun generateUniqueNumber(type: InvoiceType): String {
        var candidate = settingsRepository.consumeNextNumber(type)
        var guard = 0
        while (invoiceDao.numberExists(candidate) > 0 && guard < 1000) {
            candidate = settingsRepository.consumeNextNumber(type)
            guard++
        }
        return candidate
    }

    override suspend fun deleteInvoice(id: Long) {
        db.withTransaction {
            // برگرداندن موجودی انبار پیش از حذف فاکتور
            productDao.revertInvoiceEffect(id, DateUtils.now())
            invoiceDao.deleteById(id)
        }
    }

    override suspend fun setPayment(invoiceId: Long, status: PaymentStatus, paidAmount: Long) {
        invoiceDao.updatePayment(invoiceId, status.name, paidAmount, DateUtils.now())
    }

    private data class SalesPhase(val today: Long, val todayCount: Int, val month: Long, val monthPurchase: Long)
    private data class DebtPhase(val receivable: Long, val overdue: Int, val daily: List<Pair<Long, Long>>)
    private data class ProfitPhase(val expenses: Long, val cogs: Long, val inventory: InventorySummary)

    override fun observeDashboardSummary(): Flow<DashboardSummary> {
        val startOfToday = DateUtils.startOfToday()
        val startOfTomorrow = DateUtils.plusDays(startOfToday, 1)
        val startOfMonth = DateUtils.startOfMonthJalali()
        val sevenDaysAgo = DateUtils.daysAgo(6)

        val salesPhase = combine(
            invoiceDao.observeSumSales(startOfToday, startOfTomorrow),
            invoiceDao.observeCountSales(startOfToday, startOfTomorrow),
            invoiceDao.observeSumSales(startOfMonth, startOfTomorrow),
            invoiceDao.observeSumPurchase(startOfMonth, startOfTomorrow),
        ) { today, todayCount, month, monthPurchase ->
            SalesPhase(today, todayCount, month, monthPurchase)
        }

        val debtPhase = combine(
            invoiceDao.observeTotalReceivable(),
            invoiceDao.observeOverdueCount(DateUtils.now()),
            invoiceDao.observeDailySales(sevenDaysAgo, DateUtils.DAY_MILLIS)
                .map { rows -> rows.map { it.bucket to it.total } },
        ) { receivable, overdue, daily ->
            DebtPhase(receivable, overdue, daily)
        }

        val profitPhase = combine(
            expenseDao.observeSumInRange(startOfMonth, startOfTomorrow),
            invoiceDao.observeCogs(startOfMonth, startOfTomorrow),
            productDao.observeInventoryStats(),
            productDao.observeLowStock(),
        ) { expenses, cogs, stats, low ->
            ProfitPhase(
                expenses = expenses,
                cogs = cogs,
                inventory = InventorySummary(
                    productCount = stats.productCount,
                    lowStockCount = stats.lowStockCount,
                    outOfStockCount = stats.outOfStockCount,
                    totalStockValue = stats.totalStockValue,
                    criticalProducts = low.take(5).map { it.toDomain() },
                ),
            )
        }

        return combine(salesPhase, debtPhase, profitPhase) { s, d, p ->
            DashboardSummary(
                todaySales = s.today,
                todayInvoiceCount = s.todayCount,
                monthSales = s.month,
                monthPurchase = s.monthPurchase,
                totalReceivable = d.receivable,
                overdueCount = d.overdue,
                last7DaysSales = completeWeek(d.daily),
                monthExpenses = p.expenses,
                monthNetProfit = s.month - p.cogs - p.expenses,
                inventory = p.inventory,
            )
        }
    }

    /** پرکردن روزهای خالی تا دقیقاً ۷ نقطه داده برای نمودار */
    private fun completeWeek(rows: List<Pair<Long, Long>>): List<Pair<Long, Long>> {
        val map = rows.toMap()
        return (6 downTo 0).map { back ->
            val day = DateUtils.daysAgo(back)
            val bucket = (day / DateUtils.DAY_MILLIS) * DateUtils.DAY_MILLIS
            bucket to (map[bucket] ?: 0L)
        }
    }

    override suspend fun buildSalesReport(from: Long, to: Long): SalesReport {
        val invoices = invoiceDao.getInRange(from, to).map { it.toDomain() }
        val sales = invoices.filter { it.type == InvoiceType.SALE }
        val purchases = invoices.filter { it.type == InvoiceType.PURCHASE }
        val now = DateUtils.now()
        val daily = sales.groupBy { DateUtils.startOfDay(it.issueDate) }
            .map { (day, list) -> day to list.sumOf { it.grandTotal } }
            .sortedBy { it.first }
        return SalesReport(
            from = from,
            to = to,
            totalSales = sales.sumOf { it.grandTotal },
            totalPurchase = purchases.sumOf { it.grandTotal },
            grossProfit = sales.sumOf { it.grandTotal } - purchases.sumOf { it.grandTotal },
            paidAmount = sales.sumOf { it.paidAmount.coerceAtMost(it.grandTotal) },
            unpaidAmount = sales.sumOf { it.remainingAmount },
            overdueAmount = sales.filter { it.status != PaymentStatus.PAID && it.dueDate != null && it.dueDate < now }
                .sumOf { it.remainingAmount },
            invoiceCount = sales.size,
            dailySales = daily,
        )
    }

    override fun observeCustomerBalances(): Flow<Map<Long, CustomerBalanceRow>> =
        customerDao.observeBalances(DateUtils.now()).map { rows ->
            rows.associate {
                it.customerId to CustomerBalanceRow(
                    customerId = it.customerId,
                    totalDebt = it.totalDebt,
                    invoiceCount = it.invoiceCount,
                    lastPurchaseAt = it.lastPurchaseAt,
                    hasOverdue = it.hasOverdue,
                )
            }
        }
}
