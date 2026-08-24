package com.modir.forushgah.data.local.dao

import androidx.room.*
import com.modir.forushgah.data.local.entity.CategoryEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProductDao {
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(product: ProductEntity): Long

    @Update
    suspend fun update(product: ProductEntity)

    @Query("UPDATE products SET isActive = 0, updatedAt = :now WHERE id = :productId")
    suspend fun archive(productId: Long, now: Long)

    @Query("SELECT * FROM products WHERE isActive = 1 ORDER BY name ASC")
    fun observeActiveProducts(): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE isActive = 1 AND categoryId = :categoryId ORDER BY name ASC")
    fun observeActiveProductsByCategory(categoryId: Long): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE id = :productId")
    suspend fun getById(productId: Long): ProductEntity?

    @Query("SELECT * FROM products WHERE id = :productId")
    fun observeById(productId: Long): Flow<ProductEntity?>

    @Query("SELECT * FROM products WHERE isActive = 1 AND stockQuantity <= minimumStock ORDER BY stockQuantity ASC")
    fun observeLowStockProducts(): Flow<List<ProductEntity>>

    @Query("SELECT COALESCE(SUM(purchasePrice * stockQuantity), 0) FROM products WHERE isActive = 1")
    fun observeInventoryValueAtCost(): Flow<Long>

    @Query("""
        SELECT * FROM products
        WHERE isActive = 1 AND (name LIKE '%' || :query || '%' OR sku LIKE '%' || :query || '%' OR barcode = :query)
        ORDER BY name ASC LIMIT 30
    """)
    fun observeSearch(query: String): Flow<List<ProductEntity>>

    @Query("SELECT COUNT(*) FROM products WHERE isActive = 1")
    fun observeActiveProductCount(): Flow<Int>
}

@Dao
interface CategoryDao {
    @Insert
    suspend fun insert(category: CategoryEntity): Long

    @Update
    suspend fun update(category: CategoryEntity)

    @Query("UPDATE categories SET isActive = 0 WHERE id = :categoryId")
    suspend fun archive(categoryId: Long)

    @Query("SELECT * FROM categories WHERE isActive = 1 ORDER BY name ASC")
    fun observeAll(): Flow<List<CategoryEntity>>

    @Query("""
        SELECT categories.*, (
            SELECT COUNT(*) FROM products WHERE products.categoryId = categories.id AND products.isActive = 1
        ) AS productCount
        FROM categories WHERE categories.isActive = 1 ORDER BY categories.name ASC
    """)
    fun observeAllWithProductCount(): Flow<List<CategoryWithProductCount>>
}

data class CategoryWithProductCount(
    @Embedded val category: CategoryEntity,
    val productCount: Int,
)
