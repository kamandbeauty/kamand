package com.modir.forushgah.domain.usecase.finance

import com.modir.forushgah.core.common.Money

/**
 * Phase 4.1: computes the revenue that must be reversed when units come back
 * on a sales invoice — from the HISTORICAL price snapshots stored on the
 * order lines (not current product prices), with the original discounts
 * allocated pro-rata. No new pricing rule is invented:
 *
 *  - line discount: allocated by quantity share
 *    (`lineDiscount * returnedQty / orderedQty`, truncated — the allocation
 *    can never exceed the original discount);
 *  - order discount: allocated by gross value share
 *    (`orderDiscount * returnedGross / orderedGross`, truncated).
 *
 * Integer Toman arithmetic throughout (Money safety). Partial returns that
 * together exhaust the order reproduce the full net revenue up to a rounding
 * remainder of a few Tomans from the truncations.
 */
object ReturnRevenueCalculator {

    /** An ordered (sold) line with its historical price/discount snapshots. */
    data class OrderedLine(
        val productId: Long,
        val quantity: Int,
        val unitSellingPrice: Money,
        val discount: Money,
    )

    /** The quantity being returned for one product. */
    data class ReturnedLine(val productId: Long, val quantity: Int)

    fun reversedRevenue(
        orderedLines: List<OrderedLine>,
        orderDiscount: Money,
        returned: List<ReturnedLine>,
    ): Money {
        val orderedGross = orderedLines.sumOf { it.unitSellingPrice.amountInToman * it.quantity }
        var grossReturned = 0L
        var lineDiscountAllocated = 0L
        for (line in orderedLines) {
            if (line.quantity <= 0) continue
            val qty = (returned.firstOrNull { it.productId == line.productId }?.quantity ?: 0)
                .coerceAtMost(line.quantity)
            if (qty <= 0) continue
            grossReturned += line.unitSellingPrice.amountInToman * qty
            lineDiscountAllocated += line.discount.amountInToman * qty / line.quantity
        }
        val orderDiscountAllocated =
            if (orderedGross > 0 && grossReturned > 0) orderDiscount.amountInToman * grossReturned / orderedGross else 0L
        val reversed = (grossReturned - lineDiscountAllocated - orderDiscountAllocated).coerceAtLeast(0L)
        return Money(reversed)
    }
}
