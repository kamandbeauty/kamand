package ir.factoryar.core.domain.model

data class InvoiceTotals(
    /** جمع اقلام قبل از تخفیف */
    val subtotal: Long,
    /** جمع تخفیف آیتم‌ها + تخفیف کلی */
    val discountTotal: Long,
    val taxTotal: Long,
    val grandTotal: Long,
)

/** محاسبه‌گر خالص جمع فاکتور — قابل تست واحد */
object InvoiceCalculator {
    fun calculate(items: List<InvoiceItem>, globalDiscount: Long): InvoiceTotals {
        val subtotal = items.sumOf { it.grossAmount }
        val itemDiscounts = items.sumOf { it.discountAmount }
        val discountTotal = itemDiscounts + globalDiscount
        val taxTotal = items.sumOf { it.taxAmount }
        val grand = (subtotal - discountTotal + taxTotal).coerceAtLeast(0)
        return InvoiceTotals(subtotal, discountTotal, taxTotal, grand)
    }
}

data class DashboardSummary(
    val todaySales: Long = 0,
    val monthSales: Long = 0,
    val todayInvoiceCount: Int = 0,
    val totalReceivable: Long = 0,
    val overdueCount: Int = 0,
    val monthPurchase: Long = 0,
    /** فروش ۷ روز اخیر: (آغاز روز به millis) → جمع */
    val last7DaysSales: List<Pair<Long, Long>> = emptyList(),
    /** هزینه‌های ثبت‌شده این ماه */
    val monthExpenses: Long = 0,
    /** سود خالص تقریبی این ماه: فروش − بهای تمام‌شده − هزینه‌ها */
    val monthNetProfit: Long = 0,
    /** خلاصه انبار (کالاهای رو به اتمام) */
    val inventory: InventorySummary = InventorySummary(),
)

data class SalesReport(
    val from: Long,
    val to: Long,
    val totalSales: Long,
    val totalPurchase: Long,
    val grossProfit: Long,
    val paidAmount: Long,
    val unpaidAmount: Long,
    val overdueAmount: Long,
    val invoiceCount: Int,
    /** سری روزانه برای نمودار */
    val dailySales: List<Pair<Long, Long>>,
)

data class CustomerBalanceRow(
    val customerId: Long,
    val totalDebt: Long,
    val invoiceCount: Int,
    val lastPurchaseAt: Long?,
    val hasOverdue: Boolean,
)
