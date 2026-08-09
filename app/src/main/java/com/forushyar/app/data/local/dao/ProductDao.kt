package com.forushyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.forushyar.app.data.local.entity.Product
import kotlinx.coroutines.flow.Flow

@Dao
interface ProductDao {

    @Query("SELECT * FROM products ORDER BY createdDate DESC")
    fun observeAll(): Flow<List<Product>>

    @Query("SELECT * FROM products WHERE name LIKE '%' || :query || '%' OR category LIKE '%' || :query || '%' ORDER BY name")
    fun search(query: String): Flow<List<Product>>

    @Query("SELECT * FROM products WHERE id = :id")
    fun observeById(id: Long): Flow<Product?>

    @Query("SELECT COUNT(*) FROM products")
    fun observeCount(): Flow<Int>

    @Insert
    suspend fun insert(product: Product): Long

    @Update
    suspend fun update(product: Product)

    @Delete
    suspend fun delete(product: Product)

    @Query("DELETE FROM products WHERE id = :id")
    suspend fun deleteById(id: Long)
}
