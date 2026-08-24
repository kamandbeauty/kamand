package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

/**
 * A recorded payment against an order (spec §18). Supports full and partial
 * payments; the remaining amount is derived, never stored as a receivable
 * until the Phase 4 financial engine exists. Original payment rows are never
 * deleted when a refund occurs — refunds are separate [Refund] records.
 */
data class Payment(
    val id: Long = 0,
    val orderId: Long?,
    val amount: Money,
    val method: String, // display label, e.g. "نقدی", "کارت‌به‌کارت"
    val paymentMethodId: Long? = null, // link to the generic PaymentMethod (spec §8)
    val paidAt: Long,
    val reference: String? = null, // e.g. transaction/reference number from the bank
    val notes: String? = null,
)

/**
 * Generic, user-extensible payment method (spec §8). Deliberately separate
 * from [SalesChannel] — e.g. channel «باسلام» with method «اقساطی».
 * External platforms are never hardcoded into payment calculations.
 */
data class PaymentMethod(
    val id: Long = 0,
    val name: String, // نقدی، کارت‌به‌کارت، کارت بانکی، درگاه، اقساطی، سایر
    val isBuiltIn: Boolean = false,
)

/**
 * "Sales & Settlement Method" engine (spec section 15). Not hardcoded to
 * specific platforms — the user can define custom channels, each optionally
 * carrying a default commission used by the settlement engine (Phase 5).
 */
data class SalesChannel(
    val id: Long = 0,
    val name: String, // نقدی، کارت‌به‌کارت، درگاه، اسنپ‌پی، ترب، باسلام، ...
    val defaultCommissionPercent: Double = 0.0,
    val isBuiltIn: Boolean = false,
)

data class ShippingProvider(
    val id: Long = 0,
    val name: String, // پست، تیپاکس، پیک، ...
)

enum class ReturnReason { CUSTOMER_REFUSED, DEFECTIVE, WRONG_ITEM, OTHER }

/** Return lifecycle (spec §22). */
enum class ReturnStatus {
    REQUESTED, // درخواست شده
    APPROVED, // تأیید شده
    RECEIVED, // دریافت شده
    REFUNDED, // مبلغ برگشت داده شده
    REJECTED, // رد شده
}

/** One line of a return: how many units of a product come back (spec §21).
 * Partial returns create a row with a quantity below the ordered quantity —
 * only those units go back into inventory. */
data class OrderReturnItem(
    val id: Long = 0,
    val returnId: Long = 0,
    val productId: Long,
    val quantity: Int,
)

/**
 * A returned/refused shipment (spec §21–23). Captures return shipping cost and
 * lost packaging so Phase 4 can compute the real financial result. Restock
 * movements reference the return id (idempotent — never restocks twice).
 */
data class OrderReturn(
    val id: Long = 0,
    val orderId: Long,
    val reason: ReturnReason,
    val status: ReturnStatus = ReturnStatus.RECEIVED,
    val items: List<OrderReturnItem> = emptyList(),
    val returnShippingCost: Money = Money.ZERO,
    val packagingCostLost: Money = Money.ZERO,
    val revenueReversed: Money = Money.ZERO,
    val restockedToInventory: Boolean = true,
    val date: Long,
) {
    val totalLoss: Money get() = returnShippingCost + packagingCostLost
}

/**
 * A refund record (spec §24). Always a separate row — the original [Payment]
 * history is preserved. `amount` is the money returned to the customer.
 */
data class Refund(
    val id: Long = 0,
    val orderId: Long,
    val amount: Money,
    val date: Long,
    val method: String, // e.g. "کارت بانکی"
    val reason: String?,
    val note: String? = null,
)
