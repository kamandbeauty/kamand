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

    @Query("SELECT stockQuantity FROM products WHERE id = :productId")
    suspend fun getCurrentStock(productId: Long): Int?

    @Query("UPDATE products SET stockQuantity = :newStock, updatedAt = :now WHERE id = :productId")
    suspend fun setStock(productId: Long, newStock: Int, now: Long)
}
