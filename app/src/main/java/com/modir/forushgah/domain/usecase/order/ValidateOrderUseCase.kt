package com.modir.forushgah.domain.usecase.order

import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.validation.ValidationResult
import com.modir.forushgah.domain.validation.validationOf
import javax.inject.Inject

/** One order line as it appears in the create-order form (spec §29). */
data class OrderItemDraft(
    val productId: Long,
    val name: String,
    val quantity: Int,
    val unitSellingPrice: Money,
    val discount: Money,
    val availableStock: Int,
)

/** Everything [ValidateOrderUseCase] needs — pure values, no I/O. */
data class OrderValidationDraft(
    val customerId: Long?,
    val items: List<OrderItemDraft>,
    val orderDiscount: Money,
    val shippingChargedToCustomer: Money,
    val actualShippingCost: Money,
    val packagingCost: Money,
) {
    val productSubtotal: Money
        get() = Money.sum(items.map { Money(it.unitSellingPrice.amountInToman * it.quantity - it.discount.amountInToman) })
}

/**
 * Spec §29 — friendly Persian validation for order creation:
 * empty order, quantity <= 0, negative price/discount, discount > subtotal,
 * quantity > available stock, invalid customer, negative shipping/packaging.
 */
class ValidateOrderUseCase @Inject constructor() {
    operator fun invoke(draft: OrderValidationDraft): ValidationResult {
        val checks = buildList {
            add((draft.customerId != null) to "مشتری سفارش را انتخاب کنید")
            add((draft.items.isNotEmpty()) to "حداقل یک کالا به سفارش اضافه کنید")
            draft.items.forEach { item ->
                add((item.quantity > 0) to "تعداد «${item.name}» باید بیشتر از صفر باشد")
                add((item.unitSellingPrice.isNegative.not()) to "قیمت «${item.name}» نمی‌تواند منفی باشد")
                add((item.discount.isNegative.not()) to "تخفیف «${item.name}» نمی‌تواند منفی باشد")
                add(
                    (item.discount <= Money(item.unitSellingPrice.amountInToman * item.quantity)) to
                        "تخفیف «${item.name}» نمی‌تواند از مبلغ ردیف بیشتر باشد",
                )
                add((item.quantity <= item.availableStock) to "موجودی «${item.name}» کافی نیست (فقط ${item.availableStock} واحد)")
            }
            add((draft.orderDiscount.isNegative.not()) to "تخفیف سفارش نمی‌تواند منفی باشد")
            add((draft.orderDiscount <= draft.productSubtotal) to "تخفیف سفارش نمی‌تواند از مبلغ کالاها بیشتر باشد")
            add((draft.shippingChargedToCustomer.isNegative.not()) to "هزینه ارسال دریافتی نمی‌تواند منفی باشد")
            add((draft.actualShippingCost.isNegative.not()) to "هزینه واقعی ارسال نمی‌تواند منفی باشد")
            add((draft.packagingCost.isNegative.not()) to "هزینه بسته‌بندی نمی‌تواند منفی باشد")
        }
        return validationOf(*checks.toTypedArray())
    }
}
