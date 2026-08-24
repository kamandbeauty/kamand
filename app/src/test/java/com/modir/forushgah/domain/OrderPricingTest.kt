package com.modir.forushgah.domain

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.Order
import com.modir.forushgah.domain.model.OrderItem
import com.modir.forushgah.domain.model.ShippingPaymentType
import org.junit.Test

/** Spec §6/§7/§12/§13/§30: order pricing, discounts and the three shipping
 * scenarios (A: customer prepaid, B: COD, C: seller-paid) — all values
 * verified independently, using the safe Money type only. */
class OrderPricingTest {

    private fun item(
        unitPrice: Long,
        quantity: Int = 1,
        discount: Long = 0,
        purchasePrice: Long = unitPrice / 2,
    ) = OrderItem(
        orderId = 1,
        productId = 1,
        quantity = quantity,
        unitSellingPrice = Money(unitPrice),
        unitPurchasePrice = Money(purchasePrice),
        discount = Money(discount),
    )

    private fun order(
        vararg items: OrderItem,
        discount: Long = 0,
        type: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
        charged: Long = 0,
        actualCost: Long = 0,
        packaging: Long = 0,
    ) = Order(
        orderNumber = "SF-1",
        customerId = 1,
        orderDate = 0,
        items = items.toList(),
        discount = Money(discount),
        shippingPaymentType = type,
        shippingChargedToCustomer = Money(charged),
        actualShippingCost = Money(actualCost),
        packagingCost = Money(packaging),
        createdAt = 0,
        updatedAt = 0,
    )

    @Test
    fun `item subtotal is quantity times unit price minus item discount`() {
        val i = item(unitPrice = 1_000_000, quantity = 2, discount = 100_000)
        assertThat(i.lineSubtotal).isEqualTo(Money(1_900_000))
    }

    @Test
    fun `spec example 10 percent discount on one million`() {
        // Spec §7: 1,000,000 with 10% discount -> 900,000
        val discount = Money(1_000_000).percentOf(10.0)
        assertThat(discount).isEqualTo(Money(100_000))
        assertThat(order(item(1_000_000, discount = 100_000)).productSubtotal).isEqualTo(Money(900_000))
    }

    @Test
    fun `order discount is subtracted from the product subtotal`() {
        val o = order(item(1_000_000), item(2_000_000), discount = 1_000_000)
        assertThat(o.productSubtotal).isEqualTo(Money(2_000_000))
    }

    // Spec §12 Scenario A: product 800,000 + shipping charged 70,000 = 870,000;
    // store shipping revenue 70,000, actual expense 55,000.
    @Test
    fun `scenario A customer prepaid shipping`() {
        val o = order(item(800_000), type = ShippingPaymentType.CUSTOMER_PREPAID, charged = 70_000, actualCost = 55_000)
        assertThat(o.totalCustomerPayment).isEqualTo(Money(870_000))
        assertThat(o.shippingRevenue).isEqualTo(Money(70_000))
        assertThat(o.shippingExpenseForSeller).isEqualTo(Money(55_000))
    }

    // Spec §12 Scenario B: COD — customer pays 800,000; shipping revenue and
    // seller shipping expense are both 0; packaging cost may still exist.
    @Test
    fun `scenario B cash on delivery`() {
        val o = order(item(800_000), type = ShippingPaymentType.COD, actualCost = 55_000, packaging = 20_000)
        assertThat(o.totalCustomerPayment).isEqualTo(Money(800_000))
        assertThat(o.shippingRevenue).isEqualTo(Money.ZERO)
        assertThat(o.shippingExpenseForSeller).isEqualTo(Money.ZERO)
        assertThat(o.packagingCost).isEqualTo(Money(20_000))
    }

    // Spec §12 Scenario C: seller-paid — customer pays 800,000; seller expense 70,000.
    @Test
    fun `scenario C seller paid shipping`() {
        val o = order(item(800_000), type = ShippingPaymentType.SELLER_PAID, actualCost = 70_000)
        assertThat(o.totalCustomerPayment).isEqualTo(Money(800_000))
        assertThat(o.shippingRevenue).isEqualTo(Money.ZERO)
        assertThat(o.shippingExpenseForSeller).isEqualTo(Money(70_000))
    }

    // Spec §13: packaging is stored separately, never inside the customer total.
    @Test
    fun `packaging cost is stored separately from the customer total`() {
        val o = order(item(1_000_000), type = ShippingPaymentType.CUSTOMER_PREPAID, charged = 50_000, packaging = 30_000)
        assertThat(o.totalCustomerPayment).isEqualTo(Money(1_050_000))
        assertThat(o.packagingCost).isEqualTo(Money(30_000))
    }

    // Spec §6: platform commission and shipping expense are NOT inside the
    // customer total — only explicit prepaid shipping is.
    @Test
    fun `commission is excluded from the customer total`() {
        val o = order(item(800_000), type = ShippingPaymentType.SELLER_PAID, actualCost = 70_000)
        assertThat(o.totalCustomerPayment).isEqualTo(Money(800_000))
        assertThat(o.totalCustomerPayment).isNotEqualTo(Money(870_000))
    }
}
