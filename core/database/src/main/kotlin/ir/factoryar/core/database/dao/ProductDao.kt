package ir.factoryar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import ir.factoryar.core.database.entity.InventoryStatsRow
import ir.factoryar.core.database.entity.ProductCategoryEntity
import ir.factoryar.core.database.entity.ProductEntity
import ir.factoryar.core.database.entity.StockMovementEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProductDao {

    @Query("SELECT * FROM products WHERE active = 1 ORDER BY name COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE id = :id")
    fun observeById(id: Long): Flow<ProductEntity?>

    @Query("SELECT * FROM products WHERE id = :id")
    suspend fun getById(id: Long): ProductEntity?

    @Query("SELECT * FROM products WHERE barcode = :barcode AND active = 1 LIMIT 1")
    suspend fun findByBarcode(barcode: String): ProductEntity?

    @Query("SELECT COUNT(*) FROM products WHERE barcode = :barcode AND id != :excludeId")
    suspend fun barcodeUsedBy(barcode: String, excludeId: Long): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(product: ProductEntity): Long

    @Query("DELETE FROM products WHERE id = :id")
    suspend fun deleteById(id: Long)

    /** کسر/افزایش اتمیک موجودی (منفی مجاز است تا فروش بیش از موجودی مسدود نشود) */
    @Query("UPDATE products SET stockQuantity = stockQuantity + :delta, updatedAt = :now WHERE id = :id AND isService = 0")
    suspend fun applyStockDelta(id: Long, delta: Double, now: Long)

    // ---------------- کاردکس ----------------

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMovement(movement: StockMovementEntity): Long

    @Query("SELECT * FROM stock_movements WHERE productId = :productId ORDER BY createdAt DESC, id DESC LIMIT 200")
    fun observeMovements(productId: Long): Flow<List<StockMovementEntity>>

    @Query("DELETE FROM stock_movements WHERE invoiceId = :invoiceId")
    suspend fun deleteMovementsOfInvoice(invoiceId: Long)

    @Query("SELECT * FROM stock_movements WHERE invoiceId = :invoiceId")
    suspend fun movementsOfInvoice(invoiceId: Long): List<StockMovementEntity>

    /** برگرداندن اثر انبارِ یک فاکتور (هنگام ویرایش/حذف) */
    @Transaction
    suspend fun revertInvoiceEffect(invoiceId: Long, now: Long) {
        movementsOfInvoice(invoiceId).forEach { m ->
            applyStockDelta(m.productId, -m.quantityDelta, now)
        }
        deleteMovementsOfInvoice(invoiceId)
    }

    // ---------------- گزارش انبار ----------------

    @Query(
        """
        SELECT COUNT(*) AS productCount,
               COALESCE(SUM(CASE WHEN isService = 0 AND lowStockThreshold > 0 AND stockQuantity <= lowStockThreshold THEN 1 ELSE 0 END), 0) AS lowStockCount,
               COALESCE(SUM(CASE WHEN isService = 0 AND stockQuantity <= 0 THEN 1 ELSE 0 END), 0) AS outOfStockCount,
               COALESCE(SUM(CASE WHEN isService = 0 THEN stockQuantity * costPrice ELSE 0 END), 0) AS totalStockValue
        FROM products WHERE active = 1
        """
    )
    fun observeInventoryStats(): Flow<InventoryStatsRow>

    @Query(
        """
        SELECT * FROM products
        WHERE active = 1 AND isService = 0 AND lowStockThreshold > 0 AND stockQuantity <= lowStockThreshold
        ORDER BY (stockQuantity - lowStockThreshold) ASC, name ASC
        """
    )
    fun observeLowStock(): Flow<List<ProductEntity>>

    // ---------------- دسته‌بندی ----------------

    @Query("SELECT * FROM product_categories ORDER BY sortOrder ASC, name COLLATE NOCASE ASC")
    fun observeCategories(): Flow<List<ProductCategoryEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertCategory(category: ProductCategoryEntity): Long

    @Query("DELETE FROM product_categories WHERE id = :id")
    suspend fun deleteCategory(id: Long)
}
