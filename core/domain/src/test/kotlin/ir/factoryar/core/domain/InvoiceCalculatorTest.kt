package ir.factoryar.core.domain

import ir.factoryar.core.domain.model.InvoiceCalculator
import ir.factoryar.core.domain.model.InvoiceItem
import org.junit.Assert.assertEquals
import org.junit.Test

class InvoiceCalculatorTest {

    @Test
    fun `totals with item discount and tax`() {
        val items = listOf(
            InvoiceItem(title = "کالا ۱", quantity = 2.0, unitPrice = 100_000),        // 200,000
            InvoiceItem(title = "کالا ۲", quantity = 1.0, unitPrice = 50_000, discountPercent = 10.0, taxPercent = 10.0),
        )
        val t = InvoiceCalculator.calculate(items, globalDiscount = 5_000)
        assertEquals(250_000, t.subtotal)
        // تخفیف آیتم دوم: ۵٬۰۰۰ + تخفیف کلی ۵٬۰۰۰
        assertEquals(10_000, t.discountTotal)
        // مالیات آیتم دوم روی ۴۵٬۰۰۰ = ۴٬۵۰۰
        assertEquals(4_500, t.taxTotal)
        assertEquals(250_000 - 10_000 + 4_500, t.grandTotal)
    }

    @Test
    fun `grand total never negative`() {
        val t = InvoiceCalculator.calculate(emptyList(), globalDiscount = 1_000)
        assertEquals(0, t.grandTotal)
    }
}
