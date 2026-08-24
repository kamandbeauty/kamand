package com.modir.forushgah.domain.usecase

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.usecase.product.ProductDraft
import com.modir.forushgah.domain.usecase.product.ValidateProductUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import org.junit.Test

class ValidateProductUseCaseTest {

    private val validate = ValidateProductUseCase()

    private fun validDraft(
        name: String = "شامپو مو",
        sku: String = "SKU-1",
        sellingPrice: Money = Money(150_000),
        purchasePrice: Money = Money(90_000),
        packagingCost: Money = Money(5_000),
        stockQuantity: Int = 10,
        minimumStock: Int = 2,
    ) = ProductDraft(name, sku, sellingPrice, purchasePrice, packagingCost, stockQuantity, minimumStock)

    @Test
    fun `valid product passes validation`() {
        assertThat(validate(validDraft())).isEqualTo(ValidationResult.Valid)
    }

    @Test
    fun `blank name is rejected`() {
        val result = validate(validDraft(name = "  "))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative selling price is rejected`() {
        val result = validate(validDraft(sellingPrice = Money(-1)))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative purchase price is rejected`() {
        val result = validate(validDraft(purchasePrice = Money(-1)))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative packaging cost is rejected`() {
        val result = validate(validDraft(packagingCost = Money(-1)))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative stock is rejected`() {
        val result = validate(validDraft(stockQuantity = -1))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `negative minimum stock is rejected`() {
        val result = validate(validDraft(minimumStock = -1))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }

    @Test
    fun `zero selling price is allowed (not negative)`() {
        assertThat(validate(validDraft(sellingPrice = Money(0)))).isEqualTo(ValidationResult.Valid)
    }

    @Test
    fun `multiple errors are all collected`() {
        val result = validate(validDraft(name = "", sellingPrice = Money(-1), stockQuantity = -5))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
        val invalid = result as ValidationResult.Invalid
        assertThat(invalid.messages).hasSize(3)
    }
}
