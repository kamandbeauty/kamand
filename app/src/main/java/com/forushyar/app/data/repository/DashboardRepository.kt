package com.forushyar.app.data.repository

import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.util.DateUtils
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/** داده‌های مورد نیاز داشبورد و گزارش ساده ماه جاری. */
data class DashboardData(
    val todaySales: Long = 0,
    val todayProfit: Long = 0,
    val openOrders: Int = 0,
    val customerCount: Int = 0,
    val monthSales: Long = 0,
    val monthProfit: Long = 0,
    val monthOrderCount: Int = 0,
    val recentOrders: List<OrderDetails> = emptyList()
)

private data class DashboardSummary(
    val todaySales: Long,
    val todayProfit: Long,
    val openOrders: Int,
    val customerCount: Int,
    val recentOrders: List<OrderDetails>
)

private data class MonthlyReport(
    val sales: Long,
    val profit: Long,
    val orderCount: Int
)

@Singleton
class DashboardRepository @Inject constructor(
    private val orderDao: OrderDao,
    private val customerDao: CustomerDao
) {
    fun observeDashboard(): Flow<DashboardData> {
        val today = DateUtils.todayRange()
        val month = DateUtils.currentPersianMonthRange()

        val summary = combine(
            orderDao.observeSalesBetween(today.first, today.last),
            orderDao.observeProfitBetween(today.first, today.last),
            orderDao.observeOpenOrders(),
            customerDao.observeCount(),
            orderDao.observeRecent(RECENT_LIMIT)
        ) { sales, profit, openOrders, customerCount, recent ->
            DashboardSummary(sales, profit, openOrders, customerCount, recent)
        }

        val monthlyReport = combine(
            orderDao.observeSalesBetween(month.first, month.last),
            orderDao.observeProfitBetween(month.first, month.last),
            orderDao.observeOrderCountBetween(month.first, month.last)
        ) { sales, profit, orderCount ->
            MonthlyReport(sales, profit, orderCount)
        }

        return combine(summary, monthlyReport) { current, monthly ->
            DashboardData(
                todaySales = current.todaySales,
                todayProfit = current.todayProfit,
                openOrders = current.openOrders,
                customerCount = current.customerCount,
                monthSales = monthly.sales,
                monthProfit = monthly.profit,
                monthOrderCount = monthly.orderCount,
                recentOrders = current.recentOrders
            )
        }
    }

    private companion object {
        const val RECENT_LIMIT = 5
    }
}
