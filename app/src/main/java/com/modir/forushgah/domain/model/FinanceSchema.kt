package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class ReceivableStatus { EXPECTED, PARTIALLY_PAID, PAID, OVERDUE, CANCELLED }
enum class PayableStatus { EXPECTED, PARTIALLY_PAID, PAID, OVERDUE, CANCELLED }

/** Money owed TO the store (by a customer, installment, or platform settlement). */
data class Receivable(
    val id: Long = 0,
    val orderId: Long?,
    val customerId: Long?,
    val expectedAmount: Money,
    val expectedDate: Long,
    val receivedAmount: Money = Money.ZERO,
    val status: ReceivableStatus = ReceivableStatus.EXPECTED,
    val notes: String? = null,
) {
    val remaining: Money get() = (expectedAmount - receivedAmount).coerceAtLeastZero()
}

/** Money the store owes (to a supplier). */
data class Payable(
    val id: Long = 0,
    val supplierId: Long,
    val expectedAmount: Money,
    val dueDate: Long?,
    val paidAmount: Money = Money.ZERO,
    val status: PayableStatus = PayableStatus.EXPECTED,
    val notes: String? = null,
) {
    val remaining: Money get() = (expectedAmount - paidAmount).coerceAtLeastZero()
}

data class SupplierPayment(
    val id: Long = 0,
    val supplierId: Long,
    val payableId: Long?,
    val amount: Money,
    val paidAt: Long,
    val notes: String? = null,
)

// NOTE: ReturnReason and OrderReturn (Phase 3 shapes, spec §21–23) live in
// SalesSupport.kt — the Phase 2 copies declared here were redeclarations
// (same package com.modir.forushgah.domain.model) and broke compilation.

/**
 * Every financial event in the app writes one of these — the source of truth
 * for reports. Phase 3 uses the "*_CREATED" / "*_CANCELLED" rows as zero-amount
 * event markers (spec §25) so Phase 4 can join order lifecycle to money
 * without re-deriving history.
 */
enum class TransactionType {
    SALE, PAYMENT_RECEIVED, EXPENSE, SUPPLIER_PURCHASE, SUPPLIER_PAYMENT,
    COMMISSION, SHIPPING_EXPENSE, PACKAGING_EXPENSE, REFUND, INSTALLMENT_PAYMENT,
    ORDER_CREATED, ORDER_CANCELLED, RETURN_CREATED,
    /** Phase 4.1: revenue reversed by a sales return (negative amount).
     * Pairs with SALE so net sales = SALE + REVENUE_REVERSED. */
    REVENUE_REVERSED,
}

data class FinancialTransaction(
    val id: Long = 0,
    val type: TransactionType,
    val amount: Money, // positive = inflow, negative = outflow
    val date: Long,
    val orderId: Long? = null,
    val customerId: Long? = null,
    val supplierId: Long? = null,
    val paymentId: Long? = null,
    val refundId: Long? = null,
    val returnId: Long? = null,
    /** Generic reference escape hatch (e.g. "EXPENSE" / expense id) — kept
     * nullable and unconstrained so future event types need no schema change. */
    val referenceType: String? = null,
    val referenceId: Long? = null,
    /** Phase 4.1: set when this event is a correction that reverses another
     * event (cancellation / deletion / edit). Amount = -reversed amount. */
    val reversalOfId: Long? = null,
    val description: String? = null,
) {
    /** True when this event is a correction/reversal of [reversalOfId]. */
    val isReversal: Boolean get() = reversalOfId != null
}
