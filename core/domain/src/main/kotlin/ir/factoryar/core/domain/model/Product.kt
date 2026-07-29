package ir.factoryar.core.domain.model

import kotlinx.serialization.Serializable

/** دسته‌بندی کالا/خدمات — قابل تعریف توسط کاربر */
data class ProductCategory(
    val id: Long = 0,
    val name: String,
    /** رنگ برچسب دسته (ARGB) — اختیاری */
    val colorArgb: Long = 0xFF607D8B,
    val sortOrder: Int = 0,
)

/** کالا یا خدمات تعریف‌شده در انبار */
@Serializable
data class Product(
    val id: Long = 0,
    val name: String,
    /** بارکد (EAN/UPC/QR) — یکتا در صورت وجود */
    val barcode: String = "",
    /** کد داخلی/SKU */
    val sku: String = "",
    val categoryId: Long? = null,
    /** واحد شمارش: عدد، کیلوگرم، متر، ساعت … */
    val unit: String = "عدد",
    /** قیمت خرده‌فروشی (پیش‌فرض فاکتور فروش) */
    val retailPrice: Long = 0,
    /** قیمت عمده‌فروشی */
    val wholesalePrice: Long = 0,
    /** بهای تمام‌شده — مبنای محاسبه سود ناخالص */
    val costPrice: Long = 0,
    /** موجودی فعلی انبار */
    val stockQuantity: Double = 0.0,
    /** حد هشدار کمبود موجودی */
    val lowStockThreshold: Double = 0.0,
    /** خدمات موجودی ندارند و از کسر خودکار معاف‌اند */
    val isService: Boolean = false,
    val taxPercent: Double = 0.0,
    val note: String = "",
    val active: Boolean = true,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
) {
    /** آیا موجودی به حد هشدار رسیده است؟ */
    val isLowStock: Boolean
        get() = !isService && lowStockThreshold > 0 && stockQuantity <= lowStockThreshold

    val isOutOfStock: Boolean
        get() = !isService && stockQuantity <= 0

    /** ارزش ریالی موجودی بر مبنای بهای تمام‌شده */
    val stockValue: Long
        get() = if (isService) 0 else (stockQuantity * costPrice).toLong()

    fun priceFor(wholesale: Boolean): Long =
        if (wholesale && wholesalePrice > 0) wholesalePrice else retailPrice
}

/** کالا + نام دسته (برای نمایش در لیست) */
data class ProductWithCategory(
    val product: Product,
    val categoryName: String? = null,
)

/** دلیل تغییر موجودی */
enum class StockMoveReason(val faName: String) {
    SALE("فروش"),
    PURCHASE("خرید"),
    MANUAL("اصلاح دستی"),
    RETURN("مرجوعی"),
    INITIAL("موجودی اولیه");

    companion object {
        fun fromName(name: String?): StockMoveReason = entries.firstOrNull { it.name == name } ?: MANUAL
    }
}

/** یک رکورد در کاردکس انبار */
data class StockMovement(
    val id: Long = 0,
    val productId: Long,
    /** مثبت = ورود، منفی = خروج */
    val quantityDelta: Double,
    val reason: StockMoveReason = StockMoveReason.MANUAL,
    val invoiceId: Long? = null,
    val note: String = "",
    val createdAt: Long = 0,
)

/** خلاصه وضعیت انبار برای داشبورد */
data class InventorySummary(
    val productCount: Int = 0,
    val lowStockCount: Int = 0,
    val outOfStockCount: Int = 0,
    /** ارزش کل انبار بر مبنای بهای تمام‌شده */
    val totalStockValue: Long = 0,
    /** چند کالای بحرانی برای نمایش سریع */
    val criticalProducts: List<Product> = emptyList(),
)
