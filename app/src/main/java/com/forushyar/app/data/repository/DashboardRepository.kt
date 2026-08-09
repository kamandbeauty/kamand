package com.forushyar.app.data.repository

import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.util.DateUtils
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import javax.inject.Inject
import javax.inject.Singleton

/**
 * داده‌های مورد نیاز صفحه داشبورد.
 */
data class DashboardData(
    val todaySales: Long = 0,
    val todayProfit: Long = 0,
    val openOrders: Int = 0,
    val customerCount: Int = 0,
    val recentOrders: List<OrderDetails> = emptyList()
)

@Singleton
class DashboardRepository @Inject constructor(
    private val orderDao: OrderDao,
    private val customerDao: CustomerDao
) {
    fun observeDashboard(): Flow<DashboardData> {
        val range = DateUtils.todayRange()
        return combine(
            orderDao.observeSalesBetween(range.start, range.end),
            orderDao.observeProfitBetween(range.start, range.end),
            orderDao.observeOpenOrders(),
            customerDao.observeCount(),
            orderDao.observeRecent(RECENT_LIMIT)
        ) { sales, profit, openOrders, customerCount, recent ->
            DashboardData(
                todaySales = sales,
                todayProfit = profit,
                openOrders = openOrders,
                customerCount = customerCount,
                recentOrders = recent
            )
        }
    }

    private companion object {
        const val RECENT_LIMIT = 5
    }
}
