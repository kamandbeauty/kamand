package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.InventoryMovementEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface InventoryMovementDao {
    @Insert
    suspend fun insert(movement: InventoryMovementEntity): Long

    @Query("SELECT * FROM inventory_movements WHERE productId = :productId ORDER BY createdAt DESC")
    fun observeForProduct(productId: Long): Flow<List<InventoryMovementEntity>>

    /** Idempotency guard (spec §19/§20): count movements already written for a
     * given reference (e.g. SALE movements pointing at an order) so the same
     * order can never deduct inventory twice. */
    @Query("SELECT COUNT(*) FROM inventory_movements WHERE referenceType = :referenceType AND referenceId = :referenceId AND movementType = :movementType")
    suspend fun countByReference(referenceType: String, referenceId: Long, movementType: String): Int

    @Query("SELECT stockQuantity FROM products WHERE id = :productId")
    suspend fun getCurrentStock(productId: Long): Int?

    @Query("UPDATE products SET stockQuantity = :newStock, updatedAt = :now WHERE id = :productId")
    suspend fun setStock(productId: Long, newStock: Int, now: Long)
}
