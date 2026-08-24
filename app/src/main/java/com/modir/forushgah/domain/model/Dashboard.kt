package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class ActionSeverity { CRITICAL, HIGH, MEDIUM, INFO }

/** One row in the "امروز چه کار کنم؟" section. */
data class TodayActionItem(
    val severity: ActionSeverity,
    val label: String, // e.g. "۲ مطالبه سررسید شده"
    val count: Int,
)

data class DashboardSnapshot(
    val todaySales: Money,
    val monthSales: Money,
    val netProfit: Money,
    val todayOrderCount: Int,
    val pendingOrderCount: Int,
    val totalReceivables: Money,
    val totalPayables: Money,
    val inventoryValue: Money,
    val todayActions: List<TodayActionItem>,
) {
    val hasAnyData: Boolean
        get() = todayOrderCount > 0 || pendingOrderCount > 0 || !inventoryValue.isZero || !monthSales.isZero

    companion object {
        val EMPTY = DashboardSnapshot(
            todaySales = Money.ZERO,
            monthSales = Money.ZERO,
            netProfit = Money.ZERO,
            todayOrderCount = 0,
            pendingOrderCount = 0,
            totalReceivables = Money.ZERO,
            totalPayables = Money.ZERO,
            inventoryValue = Money.ZERO,
            todayActions = emptyList(),
        )
    }
}
