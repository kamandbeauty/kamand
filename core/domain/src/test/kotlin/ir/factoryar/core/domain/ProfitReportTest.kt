package ir.factoryar.core.domain

import ir.factoryar.core.domain.model.ExpenseByCategory
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.ProfitPoint
import ir.factoryar.core.domain.model.ProfitReport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProfitReportTest {

    @Test
    fun `سود ناخالص و خالص درست محاسبه می شود`() {
        val report = ProfitReport(
            from = 0,
            to = 100,
            revenue = 10_000_000,
            costOfGoodsSold = 6_000_000,
            operatingExpenses = 2_500_000,
        )
        assertEquals(4_000_000, report.grossProfit)
        assertEquals(1_500_000, report.netProfit)
        assertEquals(40.0, report.grossMarginPercent, 0.001)
        assertEquals(15.0, report.netMarginPercent, 0.001)
    }

    @Test
    fun `زیان به صورت عدد منفی گزارش می شود`() {
        val report = ProfitReport(
            from = 0,
            to = 100,
            revenue = 3_000_000,
            costOfGoodsSold = 2_500_000,
            operatingExpenses = 1_200_000,
        )
        assertEquals(500_000, report.grossProfit)
        assertEquals(-700_000, report.netProfit)
        assertTrue(report.netMarginPercent < 0)
    }

    @Test
    fun `درآمد صفر باعث تقسیم بر صفر نمی شود`() {
        val report = ProfitReport(from = 0, to = 1, revenue = 0, costOfGoodsSold = 0, operatingExpenses = 500_000)
        assertEquals(0.0, report.netMarginPercent, 0.0)
        assertEquals(-500_000, report.netProfit)
    }

    @Test
    fun `سود هر نقطه سری زمانی درست است`() {
        val point = ProfitPoint(
            bucketStart = 0,
            label = "۱ مهر",
            revenue = 5_000_000,
            cost = 3_000_000,
            expenses = 800_000,
        )
        assertEquals(1_200_000, point.netProfit)
    }

    @Test
    fun `سود سطر فاکتور بر مبنای بهای تمام شده محاسبه می شود`() {
        val item = InvoiceItem(
            title = "کالای آزمایشی",
            quantity = 3.0,
            unitPrice = 100_000,
            discountPercent = 10.0,
            taxPercent = 9.0,
            costPrice = 60_000,
        )
        // ناخالص = 300,000 ، تخفیف = 30,000 ، خالص = 270,000
        assertEquals(300_000, item.grossAmount)
        assertEquals(270_000, item.netAmount)
        // بهای تمام‌شده = 3 × 60,000 = 180,000
        assertEquals(180_000, item.costTotal)
        assertEquals(90_000, item.lineProfit)
    }

    @Test
    fun `کالای بدون بهای تمام شده سود برابر مبلغ خالص دارد`() {
        val item = InvoiceItem(title = "خدمات", quantity = 1.0, unitPrice = 500_000)
        assertEquals(0, item.costTotal)
        assertEquals(500_000, item.lineProfit)
    }

    @Test
    fun `مجموع دسته های هزینه برابر کل هزینه است`() {
        val categories = listOf(
            ExpenseByCategory(1, "اجاره", 5_000_000, 1),
            ExpenseByCategory(2, "قبوض", 1_200_000, 3),
            ExpenseByCategory(null, "بدون دسته", 300_000, 2),
        )
        val report = ProfitReport(
            from = 0,
            to = 1,
            revenue = 20_000_000,
            costOfGoodsSold = 8_000_000,
            operatingExpenses = categories.sumOf { it.total },
            expensesByCategory = categories,
        )
        assertEquals(6_500_000, report.operatingExpenses)
        assertEquals(5_500_000, report.netProfit)
    }
}
