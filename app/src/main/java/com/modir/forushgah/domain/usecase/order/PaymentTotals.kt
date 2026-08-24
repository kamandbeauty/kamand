package com.modir.forushgah.domain.usecase.order

import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.Payment
import com.modir.forushgah.domain.model.Refund

/**
 * Pure payment arithmetic (spec §18/§24) — testable without I/O. The
 * remaining amount is always derived, never stored as a receivable until the
 * Phase 4 financial engine exists.
 */
object PaymentTotals {
    fun paid(payments: List<Payment>): Money = Money(payments.sumOf { it.amount.amountInToman })

    fun refunded(refunds: List<Refund>): Money = Money(refunds.sumOf { it.amount.amountInToman })

    /** Customer total minus everything paid so far (never below zero). */
    fun remaining(total: Money, payments: List<Payment>): Money =
        (total - paid(payments)).coerceAtLeastZero()

    /** What may still be refunded without exceeding what was paid. */
    fun refundable(payments: List<Payment>, refunds: List<Refund>): Money =
        (paid(payments) - refunded(refunds)).coerceAtLeastZero()
}
