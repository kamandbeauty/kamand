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

enum class ReturnReason { CUSTOMER_REFUSED, DEFECTIVE, WRONG_ITEM, OTHER }

/** A returned/refused shipment (spec section 12). Captures the real financial loss. */
data class OrderReturn(
    val id: Long = 0,
    val orderId: Long,
    val reason: ReturnReason,
    val returnShippingCost: Money = Money.ZERO,
    val packagingCostLost: Money = Money.ZERO,
    val revenueReversed: Money = Money.ZERO,
    val restockedToInventory: Boolean = true,
    val date: Long,
) {
    val totalLoss: Money get() = returnShippingCost + packagingCostLost
}

/**
 * Every financial event in the app writes one of these — the source of truth
 * for reports. Phase 3 uses the *_CREATED/*_CANCELLED rows as zero-amount
 * event markers (spec §25) so Phase 4 can join order lifecycle to money
 * without re-deriving history.
 */
enum class TransactionType {
    SALE, PAYMENT_RECEIVED, EXPENSE, SUPPLIER_PURCHASE, SUPPLIER_PAYMENT,
    COMMISSION, SHIPPING_EXPENSE, PACKAGING_EXPENSE, REFUND, INSTALLMENT_PAYMENT,
    ORDER_CREATED, ORDER_CANCELLED, RETURN_CREATED,
}

data class FinancialTransaction(
    val id: Long = 0,
    val type: TransactionType,
    val amount: Money, // positive = inflow, negative = outflow
    val date: Long,
    val orderId: Long? = null,
    val description: String? = null,
)
