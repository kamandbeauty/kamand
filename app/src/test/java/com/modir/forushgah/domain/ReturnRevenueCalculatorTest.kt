package com.modir.forushgah.domain

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.usecase.finance.ReturnRevenueCalculator
import com.modir.forushgah.domain.usecase.finance.ReturnRevenueCalculator.OrderedLine
import com.modir.forushgah.domain.usecase.finance.ReturnRevenueCalculator.ReturnedLine
import org.junit.Test

/**
 * Phase 4.1: reversed revenue must come from the HISTORICAL line snapshots
 * with the original discounts allocated pro-rata — no new pricing rule.
 */
class ReturnRevenueCalculatorTest {

    private fun line(product: Long, qty: Int, price: Long, discount: Long = 0) =
        OrderedLine(product, qty, Money(price), Money(discount))

    @Test
    fun `no discount returns gross revenue`() {
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 1)),
        )
        assertThat(result).isEqualTo(Money(100_000))
    }

    @Test
    fun `line discount is allocated by quantity share`() {
        // 4 × 100k with a 40k line discount → net 90k per unit
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 4, 100_000, discount = 40_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 1)),
        )
        assertThat(result).isEqualTo(Money(90_000))
    }

    @Test
    fun `order discount is allocated by gross value share`() {
        // lines 100k×1 + 300k×1 = 400k gross; 40k order discount;
        // returning the 100k line reverses 100k − 40k×(100k/400k) = 90k
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 1, 100_000), line(2, 1, 300_000)),
            orderDiscount = Money(40_000),
            returned = listOf(ReturnedLine(1, 1)),
        )
        assertThat(result).isEqualTo(Money(90_000))
    }

    @Test
    fun `returning everything reproduces the net invoice total exactly`() {
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 1, 100_000), line(2, 1, 300_000)),
            orderDiscount = Money(40_000),
            returned = listOf(ReturnedLine(1, 1), ReturnedLine(2, 1)),
        )
        // 400k − 40k = 360k exactly
        assertThat(result).isEqualTo(Money(360_000))
    }

    @Test
    fun `line and order discounts combine pro-rata`() {
        // A: 100k×2 with 20k line discount; B: 300k×1; order discount 40k (gross 500k)
        // return 1 of A: 100k − 10k line share − 8k order share = 82k
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 2, 100_000, discount = 20_000), line(2, 1, 300_000)),
            orderDiscount = Money(40_000),
            returned = listOf(ReturnedLine(1, 1)),
        )
        assertThat(result).isEqualTo(Money(82_000))
    }

    @Test
    fun `fractional line discount truncates safely`() {
        // 3 × 100k with a 10k line discount; return 1 → 100k − 10k/3 (3,333 truncated)
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000, discount = 10_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 1)),
        )
        assertThat(result).isEqualTo(Money(96_667))
    }

    @Test
    fun `truncation never over-allocates discounts`() {
        // 1 + 2 units of the 3-unit line: 3,333 + 6,666 = 9,999 ≤ 10k discount
        val one = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000, discount = 10_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 1)),
        )
        val two = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000, discount = 10_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 2)),
        )
        val full = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000, discount = 10_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 3)),
        )
        assertThat(one.amountInToman + two.amountInToman).isAtMost(full.amountInToman + 2)
        assertThat(full).isEqualTo(Money(290_000))
    }

    @Test
    fun `zero and empty returns reverse nothing`() {
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 3, 100_000)),
            orderDiscount = Money.ZERO,
            returned = emptyList(),
        )
        assertThat(result).isEqualTo(Money.ZERO)
    }

    @Test
    fun `return quantity is capped at the ordered quantity`() {
        val result = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = listOf(line(1, 2, 100_000)),
            orderDiscount = Money.ZERO,
            returned = listOf(ReturnedLine(1, 5)),
        )
        assertThat(result).isEqualTo(Money(200_000))
    }
}
