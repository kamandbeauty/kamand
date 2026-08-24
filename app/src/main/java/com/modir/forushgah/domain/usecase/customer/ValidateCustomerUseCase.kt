package com.modir.forushgah.domain.usecase.customer

import com.modir.forushgah.domain.validation.ValidationResult
import com.modir.forushgah.domain.validation.validationOf
import javax.inject.Inject

data class CustomerDraft(
    val name: String,
    val mobile: String?,
    val address: String?,
    val city: String?,
    val notes: String?,
)

class ValidateCustomerUseCase @Inject constructor() {
    operator fun invoke(draft: CustomerDraft): ValidationResult = validationOf(
        (draft.name.isNotBlank()) to "نام مشتری را وارد کنید",
    )
}
