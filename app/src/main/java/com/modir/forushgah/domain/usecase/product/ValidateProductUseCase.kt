package com.modir.forushgah.domain.usecase.product

import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.validation.ValidationResult
import com.modir.forushgah.domain.validation.validationOf
import javax.inject.Inject

/** Draft form data for creating/editing a product — separate from the
 * persisted [com.modir.forushgah.domain.model.Product] so the UI layer can
 * hold partially-invalid input (e.g. empty name while typing) without a
 * domain model ever being invalid. */
data class ProductDraft(
    val name: String,
    val sku: String,
    val sellingPrice: Money,
    val purchasePrice: Money,
    val packagingCost: Money,
    val stockQuantity: Int,
    val minimumStock: Int,
)

class ValidateProductUseCase @Inject constructor() {
    operator fun invoke(draft: ProductDraft): ValidationResult = validationOf(
        (draft.name.isNotBlank()) to "نام محصول را وارد کنید",
        (draft.sellingPrice.amountInToman >= 0) to "قیمت فروش نمی‌تواند منفی باشد",
        (draft.purchasePrice.amountInToman >= 0) to "قیمت خرید نمی‌تواند منفی باشد",
        (draft.packagingCost.amountInToman >= 0) to "هزینه بسته‌بندی نمی‌تواند منفی باشد",
        (draft.stockQuantity >= 0) to "موجودی نمی‌تواند منفی باشد",
        (draft.minimumStock >= 0) to "حداقل موجودی نمی‌تواند منفی باشد",
    )
}
