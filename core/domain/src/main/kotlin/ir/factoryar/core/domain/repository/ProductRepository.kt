package ir.factoryar.core.domain.repository

import ir.factoryar.core.domain.model.InventorySummary
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.ProductCategory
import ir.factoryar.core.domain.model.ProductWithCategory
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.model.StockMovement
import kotlinx.coroutines.flow.Flow

/** فیلتر لیست انبار */
enum class ProductFilter(val faName: String) {
    ALL("همه"),
    LOW_STOCK("رو به اتمام"),
    OUT_OF_STOCK("ناموجود"),
    SERVICES("خدمات"),
}

interface ProductRepository {

    fun observeProducts(
        query: String = "",
        categoryId: Long? = null,
        filter: ProductFilter = ProductFilter.ALL,
    ): Flow<List<ProductWithCategory>>

    fun observeProduct(id: Long): Flow<Product?>
    suspend fun getProduct(id: Long): Product?

    /** جستجوی کالا با بارکد اسکن‌شده */
    suspend fun findByBarcode(barcode: String): Product?

    suspend fun saveProduct(product: Product): Long
    suspend fun deleteProduct(id: Long)

    /** ثبت اصلاح دستی موجودی (کاردکس) */
    suspend fun adjustStock(
        productId: Long,
        delta: Double,
        reason: StockMoveReason = StockMoveReason.MANUAL,
        invoiceId: Long? = null,
        note: String = "",
    )

    fun observeMovements(productId: Long): Flow<List<StockMovement>>

    // ---------------- دسته‌بندی ----------------
    fun observeCategories(): Flow<List<ProductCategory>>
    suspend fun saveCategory(category: ProductCategory): Long
    suspend fun deleteCategory(id: Long)

    // ---------------- گزارش ----------------
    fun observeInventorySummary(): Flow<InventorySummary>
    fun observeLowStock(): Flow<List<Product>>
}
