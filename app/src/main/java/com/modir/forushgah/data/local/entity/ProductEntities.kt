package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money

@Entity(tableName = "categories")
data class CategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val parentId: Long? = null,
    val isActive: Boolean = true,
)

@Entity(
    tableName = "products",
    foreignKeys = [
        ForeignKey(entity = CategoryEntity::class, parentColumns = ["id"], childColumns = ["categoryId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("categoryId"), Index("supplierId"), Index("sku", unique = true)],
)
data class ProductEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val sku: String,
    /** Sales unit for invoices (Rubi «واحد», default «عدد»). */
    val unit: String = "عدد",
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
)
