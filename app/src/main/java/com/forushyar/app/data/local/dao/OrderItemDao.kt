package com.forushyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import com.forushyar.app.data.local.entity.OrderItem
import kotlinx.coroutines.flow.Flow

@Dao
interface OrderItemDao {

    @Insert
    suspend fun insertAll(items: List<OrderItem>)

    @Insert
    suspend fun insert(item: OrderItem): Long

    @Delete
    suspend fun delete(item: OrderItem)

    @Query("SELECT * FROM order_items WHERE orderId = :orderId")
    fun observeForOrder(orderId: Long): Flow<List<OrderItem>>

    @Query("SELECT * FROM order_items ORDER BY id")
    suspend fun getAll(): List<OrderItem>

    @Query("DELETE FROM order_items")
    suspend fun clearAll()

    @Query("SELECT * FROM order_items WHERE orderId = :orderId")
    suspend fun getForOrder(orderId: Long): List<OrderItem>

    @Query("DELETE FROM order_items WHERE orderId = :orderId")
    suspend fun deleteByOrderId(orderId: Long)
}
