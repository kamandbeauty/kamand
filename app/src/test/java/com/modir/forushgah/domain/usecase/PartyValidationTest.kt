package com.modir.forushgah.domain.usecase

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.Product
import com.modir.forushgah.domain.usecase.customer.CustomerDraft
import com.modir.forushgah.domain.usecase.customer.ValidateCustomerUseCase
import com.modir.forushgah.domain.usecase.supplier.SupplierDraft
import com.modir.forushgah.domain.usecase.supplier.ValidateSupplierUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import org.junit.Test

class ValidateCustomerUseCaseTest {
    private val validate = ValidateCustomerUseCase()

    @Test
    fun `customer with name is valid`() {
        val result = validate(CustomerDraft(name = "علی رضایی", mobile = null, address = null, city = null, notes = null))
        assertThat(result).isEqualTo(ValidationResult.Valid)
    }

    @Test
    fun `customer with blank name is invalid`() {
        val result = validate(CustomerDraft(name = "   ", mobile = null, address = null, city = null, notes = null))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }
}

class ValidateSupplierUseCaseTest {
    private val validate = ValidateSupplierUseCase()

    @Test
    fun `supplier with name is valid`() {
        val result = validate(SupplierDraft(name = "شرکت پخش الف", phone = null, address = null, notes = null))
        assertThat(result).isEqualTo(ValidationResult.Valid)
    }

    @Test
    fun `supplier with blank name is invalid`() {
        val result = validate(SupplierDraft(name = "", phone = null, address = null, notes = null))
        assertThat(result).isInstanceOf(ValidationResult.Invalid::class.java)
    }
}

class ProductLowStockTest {

    private fun product(stock: Int, minStock: Int) = Product(
        id = 1, name = "کالا", sku = "S1", purchasePrice = Money(1000), sellingPrice = Money(2000),
        stockQuantity = stock, minimumStock = minStock, createdAt = 0, updatedAt = 0,
    )

    @Test
    fun `isLowStock true when stock at or below minimum`() {
        assertThat(product(stock = 2, minStock = 2).isLowStock).isTrue()
        assertThat(product(stock = 1, minStock = 2).isLowStock).isTrue()
    }

    @Test
    fun `isLowStock false when stock above minimum`() {
        assertThat(product(stock = 3, minStock = 2).isLowStock).isFalse()
    }

    @Test
    fun `estimated profit per unit excludes commission and shipping`() {
        // Spec §1: sellingPrice - purchasePrice - packagingCost only.
        val p = Product(
            id = 1, name = "کالا", sku = "S1",
            purchasePrice = Money(90_000), sellingPrice = Money(150_000), packagingCost = Money(5_000),
            stockQuantity = 10, minimumStock = 1, createdAt = 0, updatedAt = 0,
        )
        assertThat(p.estimatedProfitPerUnit.amountInToman).isEqualTo(55_000)
    }
}
