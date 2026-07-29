package ir.javid.hesabyar.domain.usecase

import ir.javid.hesabyar.core.model.InvoiceInput
import ir.javid.hesabyar.core.model.InvoiceLineInput
import java.math.BigDecimal
import java.math.RoundingMode

/**
 * Calculates invoice amounts in rial without cumulative floating-point error.
 * Header discount and tax are allocated to lines so line totals always equal the header total.
 */
data class CalculatedInvoiceLine(
    val grossAmount: Long,
    val discountAmount: Long,
    val taxAmount: Long,
    val totalAmount: Long
)

data class CalculatedInvoice(
    val subtotal: Long,
    val discountAmount: Long,
    val taxAmount: Long,
    val totalAmount: Long,
    val lines: List<CalculatedInvoiceLine>
)

object InvoiceCalculator {
    fun calculate(input: InvoiceInput): CalculatedInvoice {
        require(input.lines.isNotEmpty()) { "حداقل یک کالا به فاکتور اضافه کنید" }
        require(input.discountAmount >= 0 && input.taxRate >= 0 && input.taxRate.isFinite()) { "مبالغ فاکتور نامعتبرند" }

        val grossAmounts = input.lines.map { line -> lineGross(line) }
        input.lines.zip(grossAmounts).forEach { (line, gross) ->
            require(line.discountAmount in 0..gross) { "تخفیف یکی از ردیف‌ها نامعتبر است" }
        }
        val subtotal = grossAmounts.sumExact()
        val lineDiscounts = input.lines.map { it.discountAmount }
        val afterLineDiscount = grossAmounts.zip(lineDiscounts) { gross, discount -> gross - discount }
        val totalLineDiscount = lineDiscounts.sumExact()
        require(input.discountAmount <= subtotal - totalLineDiscount) { "تخفیف نمی‌تواند بیشتر از جمع فاکتور باشد" }

        val headerDiscountAllocation = allocate(input.discountAmount, afterLineDiscount)
        val lineDiscountTotals = lineDiscounts.zip(headerDiscountAllocation) { line, header -> Math.addExact(line, header) }
        val taxableBases = afterLineDiscount.zip(headerDiscountAllocation) { base, header -> base - header }
        val netBeforeTax = taxableBases.sumExact()
        val tax = if (input.taxEnabled) multiplyAndRound(netBeforeTax, input.taxRate / 100.0) else 0L
        val taxAllocation = allocate(tax, taxableBases)
        val lines = grossAmounts.indices.map { index ->
            val total = Math.addExact(taxableBases[index], taxAllocation[index])
            CalculatedInvoiceLine(grossAmounts[index], lineDiscountTotals[index], taxAllocation[index], total)
        }
        return CalculatedInvoice(
            subtotal = subtotal,
            discountAmount = Math.addExact(totalLineDiscount, input.discountAmount),
            taxAmount = tax,
            totalAmount = Math.addExact(netBeforeTax, tax),
            lines = lines
        )
    }

    private fun lineGross(line: InvoiceLineInput): Long {
        require(line.quantity > 0 && line.quantity.isFinite() && line.unitPrice >= 0) { "مقادیر یکی از ردیف‌ها نامعتبر است" }
        return multiplyAndRound(line.unitPrice, line.quantity)
    }

    private fun multiplyAndRound(amount: Long, factor: Double): Long = BigDecimal.valueOf(amount)
        .multiply(BigDecimal.valueOf(factor))
        .setScale(0, RoundingMode.HALF_UP)
        .longValueExact()

    /** Proportional allocation based on cumulative rounding; preserves exact sum even for rial remainders. */
    private fun allocate(total: Long, weights: List<Long>): List<Long> {
        if (total == 0L) return List(weights.size) { 0L }
        val weightTotal = weights.sumExact()
        require(weightTotal > 0L) { "مبلغ قابل تخصیص نامعتبر است" }
        var cumulativeWeight = 0L
        var allocated = 0L
        return weights.mapIndexed { index, weight ->
            cumulativeWeight = Math.addExact(cumulativeWeight, weight)
            val current = if (index == weights.lastIndex) total else BigDecimal.valueOf(total)
                .multiply(BigDecimal.valueOf(cumulativeWeight))
                .divide(BigDecimal.valueOf(weightTotal), 0, RoundingMode.HALF_UP)
                .longValueExact()
            (current - allocated).also { allocated = current }
        }
    }

    private fun List<Long>.sumExact(): Long = fold(0L) { total, value -> Math.addExact(total, value) }
}
