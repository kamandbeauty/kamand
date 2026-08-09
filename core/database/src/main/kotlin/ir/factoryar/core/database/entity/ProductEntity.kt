package ir.factoryar.core.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "product_categories",
    indices = [Index(value = ["name"], unique = true)],
)
data class ProductCategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val colorArgb: Long = 0xFF607D8B,
    val sortOrder: Int = 0,
)

@Entity(
    tableName = "products",
    foreignKeys = [
        ForeignKey(
            entity = ProductCategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index(value = ["name"]),
        Index(value = ["barcode"], unique = true),
        Index(value = ["categoryId"]),
        Index(value = ["active"]),
    ],
)
data class ProductEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** خالی به‌معنای نبود بارکد است؛ برای رعایت یکتایی، خالی‌ها به null نگاشت می‌شوند */
    val barcode: String?,
    val sku: String = "",
    val categoryId: Long? = null,
    val unit: String = "عدد",
    val retailPrice: Long = 0,
    val wholesalePrice: Long = 0,
    val costPrice: Long = 0,
    val stockQuantity: Double = 0.0,
    val lowStockThreshold: Double = 0.0,
    val isService: Boolean = false,
    val taxPercent: Double = 0.0,
    val note: String = "",
    val active: Boolean = true,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
)

@Entity(
    tableName = "stock_movements",
    foreignKeys = [
        ForeignKey(
            entity = ProductEntity::class,
            parentColumns = ["id"],
            childColumns = ["productId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["productId"]), Index(value = ["invoiceId"]), Index(value = ["createdAt"])],
)
data class StockMovementEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val productId: Long,
    /** مثبت = ورود، منفی = خروج */
    val quantityDelta: Double,
    /** SALE / PURCHASE / MANUAL / RETURN / INITIAL */
    val reason: String,
    val invoiceId: Long? = null,
    val note: String = "",
    val createdAt: Long = 0,
)

/** ردیف خروجی کوئری خلاصه انبار */
data class InventoryStatsRow(
    val productCount: Int,
    val lowStockCount: Int,
    val outOfStockCount: Int,
    val totalStockValue: Long,
)
