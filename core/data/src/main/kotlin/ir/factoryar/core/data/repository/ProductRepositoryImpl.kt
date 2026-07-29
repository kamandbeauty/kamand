package ir.factoryar.core.data.repository

import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.database.dao.ProductDao
import ir.factoryar.core.database.entity.StockMovementEntity
import ir.factoryar.core.domain.model.InventorySummary
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.ProductCategory
import ir.factoryar.core.domain.model.ProductWithCategory
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.model.StockMovement
import ir.factoryar.core.domain.repository.ProductFilter
import ir.factoryar.core.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProductRepositoryImpl @Inject constructor(
    private val productDao: ProductDao,
) : ProductRepository {

    override fun observeProducts(
        query: String,
        categoryId: Long?,
        filter: ProductFilter,
    ): Flow<List<ProductWithCategory>> =
        combine(productDao.observeAll(), productDao.observeCategories()) { products, categories ->
            val categoryNames = categories.associate { it.id to it.name }
            products.asSequence()
                .map { it.toDomain() }
                .filter { categoryId == null || it.categoryId == categoryId }
                .filter { p ->
                    when (filter) {
                        ProductFilter.ALL -> true
                        ProductFilter.LOW_STOCK -> p.isLowStock
                        ProductFilter.OUT_OF_STOCK -> p.isOutOfStock
                        ProductFilter.SERVICES -> p.isService
                    }
                }
                .filter { p ->
                    query.isBlank() ||
                        p.name.contains(query, ignoreCase = true) ||
                        p.barcode.contains(query, ignoreCase = true) ||
                        p.sku.contains(query, ignoreCase = true)
                }
                .map { ProductWithCategory(it, it.categoryId?.let(categoryNames::get)) }
                .toList()
        }

    override fun observeProduct(id: Long): Flow<Product?> =
        productDao.observeById(id).map { it?.toDomain() }

    override suspend fun getProduct(id: Long): Product? = productDao.getById(id)?.toDomain()

    override suspend fun findByBarcode(barcode: String): Product? =
        productDao.findByBarcode(barcode.trim())?.toDomain()

    override suspend fun saveProduct(product: Product): Long {
        val now = DateUtils.now()
        val isNew = product.id == 0L
        // جلوگیری از تکراری‌شدن بارکد
        val barcode = product.barcode.trim()
        val safeBarcode = if (barcode.isNotBlank() && productDao.barcodeUsedBy(barcode, product.id) > 0) {
            "" // بارکد تکراری نادیده گرفته می‌شود
        } else {
            barcode
        }
        val entity = product.copy(
            barcode = safeBarcode,
            createdAt = if (isNew) now else product.createdAt,
            updatedAt = now,
        ).toEntity()
        val id = productDao.upsert(entity)
        val realId = if (isNew) id else product.id
        // ثبت موجودی اولیه در کاردکس
        if (isNew && !product.isService && product.stockQuantity != 0.0) {
            productDao.insertMovement(
                StockMovementEntity(
                    productId = realId,
                    quantityDelta = product.stockQuantity,
                    reason = StockMoveReason.INITIAL.name,
                    note = "موجودی اولیه",
                    createdAt = now,
                ),
            )
        }
        return realId
    }

    override suspend fun deleteProduct(id: Long) = productDao.deleteById(id)

    override suspend fun adjustStock(
        productId: Long,
        delta: Double,
        reason: StockMoveReason,
        invoiceId: Long?,
        note: String,
    ) {
        if (delta == 0.0) return
        val now = DateUtils.now()
        productDao.applyStockDelta(productId, delta, now)
        productDao.insertMovement(
            StockMovementEntity(
                productId = productId,
                quantityDelta = delta,
                reason = reason.name,
                invoiceId = invoiceId,
                note = note,
                createdAt = now,
            ),
        )
    }

    override fun observeMovements(productId: Long): Flow<List<StockMovement>> =
        productDao.observeMovements(productId).map { list -> list.map { it.toDomain() } }

    override fun observeCategories(): Flow<List<ProductCategory>> =
        productDao.observeCategories().map { list -> list.map { it.toDomain() } }

    override suspend fun saveCategory(category: ProductCategory): Long =
        productDao.upsertCategory(category.toEntity())

    override suspend fun deleteCategory(id: Long) = productDao.deleteCategory(id)

    override fun observeInventorySummary(): Flow<InventorySummary> =
        combine(productDao.observeInventoryStats(), productDao.observeLowStock()) { stats, low ->
            InventorySummary(
                productCount = stats.productCount,
                lowStockCount = stats.lowStockCount,
                outOfStockCount = stats.outOfStockCount,
                totalStockValue = stats.totalStockValue,
                criticalProducts = low.take(5).map { it.toDomain() },
            )
        }

    override fun observeLowStock(): Flow<List<Product>> =
        productDao.observeLowStock().map { list -> list.map { it.toDomain() } }
}
