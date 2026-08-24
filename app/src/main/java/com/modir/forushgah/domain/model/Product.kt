package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

data class Product(
    val id: Long = 0,
    val name: String,
    val sku: String,
    val barcode: String? = null,
    val imageUri: String? = null,
    val categoryId: Long? = null,
    val purchasePrice: Money,
    val sellingPrice: Money,
    val stockQuantity: Int,
    val minimumStock: Int = 0,
    val supplierId: Long? = null,
    val packagingCost: Money = Money.ZERO,
    val notes: String? = null,
    val isActive: Boolean = true,
    val createdAt: Long,
    val updatedAt: Long,
) {
    /** Estimated per-unit profit ignoring order-level costs like shipping/commission. */
    val estimatedProfitPerUnit: Money
        get() = sellingPrice - purchasePrice - packagingCost

    val isLowStock: Boolean
        get() = stockQuantity <= minimumStock
}

data class Category(
    val id: Long = 0,
    val name: String,
    val parentId: Long? = null,
    val isActive: Boolean = true,
    val productCount: Int = 0,
)
