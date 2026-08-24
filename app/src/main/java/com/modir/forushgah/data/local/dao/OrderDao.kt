package com.modir.forushgah.data.local.dao

import androidx.room.*
import com.modir.forushgah.data.local.entity.OrderEntity
import com.modir.forushgah.data.local.entity.OrderItemEntity
import com.modir.forushgah.domain.model.OrderStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface OrderDao {
    @Insert
    suspend fun insertOrder(order: OrderEntity): Long

    @Insert
    suspend fun insertItems(items: List<OrderItemEntity>)

    @Update
    suspend fun updateOrder(order: OrderEntity)

    @Query("SELECT * FROM orders ORDER BY orderDate DESC")
    fun observeAll(): Flow<List<OrderEntity>>

    @Query("SELECT * FROM orders WHERE id = :id")
    suspend fun getById(id: Long): OrderEntity?

    @Query("SELECT * FROM order_items WHERE orderId = :orderId")
    suspend fun getItems(orderId: Long): List<OrderItemEntity>

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY orderDate DESC")
    fun observeByStatus(status: OrderStatus): Flow<List<OrderEntity>>

    @Query("SELECT COUNT(*) FROM orders WHERE orderDate BETWEEN :startOfDay AND :endOfDay")
    fun observeTodayOrderCount(startOfDay: Long, endOfDay: Long): Flow<Int>

    @Query("SELECT COUNT(*) FROM orders WHERE status IN ('NEW','CONFIRMED','PREPARING')")
    fun observePendingOrderCount(): Flow<Int>
}
