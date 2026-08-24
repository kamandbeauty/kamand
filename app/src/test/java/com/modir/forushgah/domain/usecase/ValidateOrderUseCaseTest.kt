package com.modir.forushgah.domain.usecase

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.usecase.order.OrderItemDraft
import com.modir.forushgah.domain.usecase.order.OrderValidationDraft
import com.modir.forushgah.domain.usecase.order.ValidateOrderUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import org.junit.Test

/** Spec §29: friendly validation for order creation. */
class ValidateOrderUseCaseTest {

    private val validate = ValidateOrderUseCase()

    private fun item(
        name: String = "کالا",
        quantity: Int = 2,
        price: Long = 100_000,
        discount: Long = 0,
        stock: Int = 10,
    ) = OrderItemDraft(productId = 1, name = name, quantity = quantity, unitSellingPrice = Money(price), discount = Money(discount), availableStock = stock)

    private fun draft(
        items: List<OrderItemDraft> = listOf(item()),
        customerId: Long? = 1,
        orderDiscount: Long = 0,
        shippingCharged: Long = 0,
        actualShipping: Long = 0,
        packaging: Long = 0,
    ) = OrderValidationDraft(
        customerId = customerId,
        items = items,
        orderDiscount = Money(orderDiscount),
        shippingChargedToCustomer = Money(shippingCharged),
        actualShippingCost = Money(actualShipping),
        packagingCost = Money(packaging),
    )

    @Test
    fun `valid order passes`() {
        assertThat(validate(draft())).isEqualTo(ValidationResult.Valid)
    }

    @Test
    fun `empty order is rejected`() {
        assertThat(validate(draft(items = emptyList()))).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `missing customer is rejected`() {
        assertThat(validate(draft(customerId = null))).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `zero quantity is rejected`() {
        assertThat(validate(draft(items = listOf(item(quantity = 0)))))
            .isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `quantity above available stock is rejected`() {
        assertThat(validate(draft(items = listOf(item(quantity = 11, stock = 10)))))
            .isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `item discount above line total is rejected`() {
        // 1,000 x 1 with a 2,000 discount
        assertThat(validate(draft(items = listOf(item(quantity = 1, price = 1_000, discount = 2_000)))))
            .isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `order discount above subtotal is rejected`() {
        // subtotal 100,000; order discount 300,000
        assertThat(validate(draft(items = listOf(item(quantity = 1, price = 100_000)), orderDiscount = 300_000)))
            .isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative shipping amounts are rejected`() {
        assertThat(validate(draft(shippingCharged = -1))).isInstanceOf(ValidationResult.Invalid::class.java)
        assertThat(validate(draft(actualShipping = -1))).isInstanceOf(ValidationResult.Invalid::class.java)
        assertThat(validate(draft(packaging = -1))).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `multiple errors are all collected`() {
        val result = validate(draft(items = emptyList(), customerId = null, shippingCharged = -5))
        val invalid = result as ValidationResult.Invalid
        // no customer + empty order + negative shipping
        assertThat(invalid.messages).hasSize(3)
    }
}
