package com.modir.forushgah.data.repository

import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.dao.OrderDao
import com.modir.forushgah.data.local.dao.PayableDao
import com.modir.forushgah.data.local.dao.ProductDao
import com.modir.forushgah.data.local.dao.ReceivableDao
import com.modir.forushgah.domain.model.ActionSeverity
import com.modir.forushgah.domain.model.DashboardSnapshot
import com.modir.forushgah.domain.model.TodayActionItem
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Combines several DAO-level flows into a single [DashboardSnapshot].
 * This lives in the repository layer (not a use-case) because Phase 1 keeps
 * it as a simple read-model aggregation; a dedicated GetDashboardSnapshot
 * use-case can wrap this later once more business rules (e.g. profit
 * recalculation) move in.
 */
@Singleton
class DashboardRepository @Inject constructor(
    private val orderDao: OrderDao,
    private val productDao: ProductDao,
    private val receivableDao: ReceivableDao,
    private val payableDao: PayableDao,
) {
    fun observeSnapshot(): Flow<DashboardSnapshot> {
        val (startOfDay, endOfDay) = todayRange()

        return combine(
            orderDao.observeTodayOrderCount(startOfDay, endOfDay),
            orderDao.observePendingOrderCount(),
            receivableDao.observeTotalOutstanding(),
            receivableDao.observeOverdue(),
            payableDao.observeTotalOutstanding(),
            productDao.observeInventoryValueAtCost(),
            productDao.observeLowStockProducts(),
        ) { values ->
            @Suppress("UNCHECKED_CAST")
            val todayOrderCount = values[0] as Int
            val pendingOrderCount = values[1] as Int
            val totalReceivable = Money(values[2] as Long)
            val overdueReceivables = values[3] as List<com.modir.forushgah.data.local.entity.ReceivableEntity>
            val totalPayable = Money(values[4] as Long)
            val inventoryValue = Money(values[5] as Long)
            val lowStockProducts = values[6] as List<com.modir.forushgah.data.local.entity.ProductEntity>

            val actions = buildList {
                if (overdueReceivables.isNotEmpty()) {
                    add(TodayActionItem(ActionSeverity.CRITICAL, "${overdueReceivables.size} مطالبه سررسید شده", overdueReceivables.size))
                }
                if (pendingOrderCount > 0) {
                    add(TodayActionItem(ActionSeverity.HIGH, "$pendingOrderCount سفارش آماده پیگیری", pendingOrderCount))
                }
                if (lowStockProducts.isNotEmpty()) {
                    add(TodayActionItem(ActionSeverity.MEDIUM, "موجودی ${lowStockProducts.size} کالا کم است", lowStockProducts.size))
                }
            }

            // Phase 1 dashboard shell: monthSales/netProfit wired to zero placeholders
            // until the financial-transaction aggregation use-cases land in Phase 4.
            DashboardSnapshot(
                todaySales = Money.ZERO,
                monthSales = Money.ZERO,
                netProfit = Money.ZERO,
                todayOrderCount = todayOrderCount,
                pendingOrderCount = pendingOrderCount,
                totalReceivables = totalReceivable,
                totalPayables = totalPayable,
                inventoryValue = inventoryValue,
                todayActions = actions,
            )
        }
    }

    private fun todayRange(): Pair<Long, Long> {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.DAY_OF_MONTH, 1)
        val end = cal.timeInMillis - 1
        return start to end
    }
}
