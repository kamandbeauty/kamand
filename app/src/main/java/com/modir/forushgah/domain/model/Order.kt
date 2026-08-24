package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class OrderStatus {
    NEW, CONFIRMED, PREPARING, SHIPPED, DELIVERED, RETURNED, CANCELLED
}

/**
 * Invoice kind (Phase 3.1 / Rubi «type»): a sales invoice is the standard
 * customer order (stock out, SALE movements); a purchase invoice records a
 * buy from a supplier (stock in, PURCHASE movements).
 */
enum class OrderKind {
    SALES, PURCHASE
}

enum class ShippingPaymentType {
    SELLER_PAID, // پرداخت توسط فروشنده
    CUSTOMER_PREPAID, // پرداخت توسط مشتری (پیش‌پرداختی)
    COD, // پس‌کرایه
}

data class OrderItem(
    val id: Long = 0,
    val orderId: Long = 0,
    /** Null for free/manual invoice lines (Rubi free items) — those never
     * touch inventory. */
    val productId: Long? = null,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money, // snapshot at time of sale, for accurate historical profit
    val discount: Money = Money.ZERO,
    /** Display name snapshot (product name when product-linked, free text for
     * manual lines) — Rubi invoice items are title-based. */
    val title: String = "",
    /** Sales unit for the line (Rubi «واحد»). */
    val unit: String = "عدد",
) {
    val lineSubtotal: Money get() = (unitSellingPrice * quantity) - discount
    val lineCost: Money get() = unitPurchasePrice * quantity
}

data class Order(
    val id: Long = 0,
    val orderNumber: String,
    val customerId: Long?,
    /** Set for purchase invoices (supplier side); null for sales invoices. */
    val supplierId: Long? = null,
    val kind: OrderKind = OrderKind.SALES,
    val orderDate: Long,
    val items: List<OrderItem>,
    val discount: Money = Money.ZERO,
    val shippingChargedToCustomer: Money = Money.ZERO,
    val paymentMethodId: Long? = null,
    val salesChannelId: Long? = null,
    val status: OrderStatus = OrderStatus.NEW,
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
    val actualShippingCost: Money = Money.ZERO,
    val packagingCost: Money = Money.ZERO,
    val commission: Money = Money.ZERO,
    val notes: String? = null,
    /** Phase 3.1: shipment tracking (String — leading zeros/letters preserved). */
    val trackingCode: String? = null,
    val shippedAt: Long? = null,
    val createdAt: Long,
    val updatedAt: Long,
) {
    val productSubtotal: Money get() = Money.sum(items.map { it.lineSubtotal }) - discount

    /** Total the customer actually pays the seller (excludes COD shipping, which the
     * customer pays to the courier directly, not to the seller). */
    val totalCustomerPayment: Money
        get() = productSubtotal + when (shippingPaymentType) {
            ShippingPaymentType.CUSTOMER_PREPAID -> shippingChargedToCustomer
            ShippingPaymentType.SELLER_PAID, ShippingPaymentType.COD -> Money.ZERO
        }

    val shippingRevenue: Money
        get() = if (shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) shippingChargedToCustomer else Money.ZERO

    val shippingExpenseForSeller: Money
        get() = when (shippingPaymentType) {
            ShippingPaymentType.COD -> Money.ZERO
            ShippingPaymentType.SELLER_PAID, ShippingPaymentType.CUSTOMER_PREPAID -> actualShippingCost
        }

    val shippingMargin: Money get() = shippingRevenue - shippingExpenseForSeller

    val totalProductCost: Money get() = Money.sum(items.map { it.lineCost })

    /** The "Real Profit" for this order — see spec section 22. */
    val realProfit: Money
        get() = productSubtotal - totalProductCost - commission - shippingExpenseForSeller + shippingRevenue - packagingCost
}
