package com.modir.forushgah.domain.usecase.supplier

import com.modir.forushgah.domain.validation.ValidationResult
import com.modir.forushgah.domain.validation.validationOf
import javax.inject.Inject

data class SupplierDraft(
    val name: String,
    val phone: String?,
    val address: String?,
    val notes: String?,
)

class ValidateSupplierUseCase @Inject constructor() {
    operator fun invoke(draft: SupplierDraft): ValidationResult = validationOf(
        (draft.name.isNotBlank()) to "نام تأمین‌کننده را وارد کنید",
    )
}
