package com.modir.forushgah.domain.usecase

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.Payment
import com.modir.forushgah.domain.model.Refund
import com.modir.forushgah.domain.usecase.order.PaymentTotals
import org.junit.Test

/** Spec §18/§30: full payment, partial payment and refund arithmetic. */
class PaymentTotalsTest {

    private fun payment(id: Long, amount: Long) = Payment(
        id = id, orderId = 1, amount = Money(amount), method = "نقدی", paidAt = 0,
    )

    private fun refund(id: Long, amount: Long) = Refund(
        id = id, orderId = 1, amount = Money(amount), date = 0, method = "کارت بانکی", reason = "مرجوعی",
    )

    // Spec §18 example: order 5,000,000; paid 3,000,000; remaining 2,000,000.
    @Test
    fun `partial payment leaves the correct remaining amount`() {
        val remaining = PaymentTotals.remaining(Money(5_000_000), listOf(payment(1, 3_000_000)))
        assertThat(remaining).isEqualTo(Money(2_000_000))
    }

    @Test
    fun `full payment leaves zero remaining`() {
        val remaining = PaymentTotals.remaining(Money(5_000_000), listOf(payment(1, 2_000_000), payment(2, 3_000_000)))
        assertThat(remaining).isEqualTo(Money.ZERO)
    }

    @Test
    fun `payments beyond the total never drive remaining below zero`() {
        val remaining = PaymentTotals.remaining(Money(5_000_000), listOf(payment(1, 6_000_000)))
        assertThat(remaining).isEqualTo(Money.ZERO)
    }

    @Test
    fun `refunds reduce the refundable amount but keep payment history intact`() {
        val payments = listOf(payment(1, 3_000_000), payment(2, 2_000_000))
        val refunds = listOf(refund(1, 1_000_000))
        assertThat(PaymentTotals.paid(payments)).isEqualTo(Money(5_000_000))
        assertThat(PaymentTotals.refunded(refunds)).isEqualTo(Money(1_000_000))
        assertThat(PaymentTotals.refundable(payments, refunds)).isEqualTo(Money(4_000_000))
    }

    @Test
    fun `refundable never goes below zero`() {
        val payments = listOf(payment(1, 1_000_000))
        val refunds = listOf(refund(1, 1_500_000))
        assertThat(PaymentTotals.refundable(payments, refunds)).isEqualTo(Money.ZERO)
    }
}
