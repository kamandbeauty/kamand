package ir.javid.hesabyar.domain.usecase

import ir.javid.hesabyar.core.model.InvoiceInput
import ir.javid.hesabyar.core.model.InvoiceLineInput
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class InvoiceCalculatorTest {
    @Test fun `line totals always equal invoice total after header discount and tax allocation`() {
        val result = InvoiceCalculator.calculate(
            InvoiceInput(
                dateEpochDay = 20_000,
                lines = listOf(
                    InvoiceLineInput(productId = 1, quantity = 1.25, unitPrice = 10_001, discountAmount = 1),
                    InvoiceLineInput(productId = 2, quantity = 2.0, unitPrice = 8_003, discountAmount = 2)
                ),
                discountAmount = 3,
                taxEnabled = true,
                taxRate = 10.0
            )
        )

        assertEquals(result.totalAmount, result.lines.sumOf { it.totalAmount })
        assertEquals(result.discountAmount, result.lines.sumOf { it.discountAmount })
        assertEquals(result.taxAmount, result.lines.sumOf { it.taxAmount })
    }

    @Test fun `discount larger than available amount is rejected`() {
        try {
            InvoiceCalculator.calculate(
                InvoiceInput(
                    dateEpochDay = 20_000,
                    lines = listOf(InvoiceLineInput(productId = 1, quantity = 1.0, unitPrice = 100)),
                    discountAmount = 101
                )
            )
            fail("Expected an invalid discount to be rejected")
        } catch (_: IllegalArgumentException) {
            // Expected.
        }
    }
}
