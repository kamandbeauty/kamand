package com.modir.forushgah.data.repository

import com.modir.forushgah.data.local.dao.CategoryDao
import com.modir.forushgah.data.local.dao.CategoryWithProductCount
import com.modir.forushgah.data.local.dao.ProductDao
import com.modir.forushgah.data.local.entity.CategoryEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.domain.model.Category
import com.modir.forushgah.domain.model.Product
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProductRepository @Inject constructor(
    private val productDao: ProductDao,
) {
    fun observeActiveProducts(): Flow<List<Product>> =
        productDao.observeActiveProducts().map { list -> list.map { it.toDomain() } }

    fun observeActiveProductsByCategory(categoryId: Long): Flow<List<Product>> =
        productDao.observeActiveProductsByCategory(categoryId).map { list -> list.map { it.toDomain() } }

    fun observeLowStockProducts(): Flow<List<Product>> =
        productDao.observeLowStockProducts().map { list -> list.map { it.toDomain() } }

    fun observeSearch(query: String): Flow<List<Product>> =
        productDao.observeSearch(query).map { list -> list.map { it.toDomain() } }

    fun observeById(productId: Long): Flow<Product?> =
        productDao.observeById(productId).map { it?.toDomain() }

    suspend fun getById(productId: Long): Product? = productDao.getById(productId)?.toDomain()

    fun observeActiveProductCount(): Flow<Int> = productDao.observeActiveProductCount()

    /** Creates a product. Stock is set directly here ONLY at creation time
     * (an initial stock count is not a "movement" — there was no prior stock
     * to move from). Every change AFTER creation must go through
     * [InventoryRepository]. */
    suspend fun create(product: Product): Long = productDao.insert(product.toEntity())

    suspend fun update(product: Product) = productDao.update(product.toEntity())

    suspend fun archive(productId: Long, now: Long = System.currentTimeMillis()) =
        productDao.archive(productId, now)
}

@Singleton
class CategoryRepository @Inject constructor(
    private val categoryDao: CategoryDao,
) {
    fun observeAll(): Flow<List<Category>> =
        categoryDao.observeAllWithProductCount().map { list -> list.map { it.toDomain() } }

    suspend fun create(name: String, parentId: Long? = null): Long =
        categoryDao.insert(CategoryEntity(name = name, parentId = parentId))

    suspend fun rename(categoryId: Long, newName: String, parentId: Long?) =
        categoryDao.update(CategoryEntity(id = categoryId, name = newName, parentId = parentId))

    suspend fun archive(categoryId: Long) = categoryDao.archive(categoryId)
}

private fun ProductEntity.toDomain() = Product(
    id = id, name = name, sku = sku, barcode = barcode, imageUri = imageUri,
    categoryId = categoryId, purchasePrice = purchasePrice, sellingPrice = sellingPrice,
    stockQuantity = stockQuantity, minimumStock = minimumStock, supplierId = supplierId,
    packagingCost = packagingCost, notes = notes, isActive = isActive,
    createdAt = createdAt, updatedAt = updatedAt,
)

private fun Product.toEntity() = ProductEntity(
    id = id, name = name, sku = sku, barcode = barcode, imageUri = imageUri,
    categoryId = categoryId, purchasePrice = purchasePrice, sellingPrice = sellingPrice,
    stockQuantity = stockQuantity, minimumStock = minimumStock, supplierId = supplierId,
    packagingCost = packagingCost, notes = notes, isActive = isActive,
    createdAt = createdAt, updatedAt = updatedAt,
)

private fun CategoryWithProductCount.toDomain() = Category(
    id = category.id, name = category.name, parentId = category.parentId,
    isActive = category.isActive, productCount = productCount,
)
