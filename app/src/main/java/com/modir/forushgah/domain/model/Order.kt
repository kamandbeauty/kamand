package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class OrderStatus {
    NEW, CONFIRMED, PREPARING, SHIPPED, DELIVERED, RETURNED, CANCELLED
}

enum class ShippingPaymentType {
    SELLER_PAYS,
    CUSTOMER_PAYS_IN_ADVANCE,
    CASH_ON_DELIVERY, // پس‌کرایه
}

data class OrderItem(
    val id: Long = 0,
    val orderId: Long = 0,
    val productId: Long,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money, // snapshot at time of sale, for accurate historical profit
    val discount: Money = Money.ZERO,
) {
    val lineSubtotal: Money get() = (unitSellingPrice * quantity) - discount
    val lineCost: Money get() = unitPurchasePrice * quantity
}

data class Order(
    val id: Long = 0,
    val orderNumber: String,
    val customerId: Long?,
    val orderDate: Long,
    val items: List<OrderItem>,
    val discount: Money = Money.ZERO,
    val shippingChargedToCustomer: Money = Money.ZERO,
    val paymentMethodId: Long? = null,
    val salesChannelId: Long? = null,
    val status: OrderStatus = OrderStatus.NEW,
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAYS,
    val actualShippingCost: Money = Money.ZERO,
    val packagingCost: Money = Money.ZERO,
    val commission: Money = Money.ZERO,
    val notes: String? = null,
) {
    val productSubtotal: Money get() = Money.sum(items.map { it.lineSubtotal }) - discount

    /** Total the customer actually pays the seller (excludes COD shipping, which the
     * customer pays to the courier directly, not to the seller). */
    val totalCustomerPayment: Money
        get() = productSubtotal + when (shippingPaymentType) {
            ShippingPaymentType.CUSTOMER_PAYS_IN_ADVANCE -> shippingChargedToCustomer
            ShippingPaymentType.SELLER_PAYS, ShippingPaymentType.CASH_ON_DELIVERY -> Money.ZERO
        }

    val shippingRevenue: Money
        get() = if (shippingPaymentType == ShippingPaymentType.CUSTOMER_PAYS_IN_ADVANCE) shippingChargedToCustomer else Money.ZERO

    val shippingExpenseForSeller: Money
        get() = when (shippingPaymentType) {
            ShippingPaymentType.CASH_ON_DELIVERY -> Money.ZERO
            ShippingPaymentType.SELLER_PAYS, ShippingPaymentType.CUSTOMER_PAYS_IN_ADVANCE -> actualShippingCost
        }

    val shippingMargin: Money get() = shippingRevenue - shippingExpenseForSeller

    val totalProductCost: Money get() = Money.sum(items.map { it.lineCost })

    /** The "Real Profit" for this order — see spec section 22. */
    val realProfit: Money
        get() = productSubtotal - totalProductCost - commission - shippingExpenseForSeller + shippingRevenue - packagingCost
}
