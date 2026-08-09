package com.forushyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.forushyar.app.data.local.entity.Order
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.data.local.entity.OrderStatus
import com.forushyar.app.data.local.entity.OrderWithItems
import kotlinx.coroutines.flow.Flow

@Dao
interface OrderDao {

    // ---------- خواندن ----------

    @Query("SELECT * FROM orders ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<OrderDetails>>

    @Query("SELECT * FROM orders ORDER BY createdAt DESC LIMIT :limit")
    fun observeRecent(limit: Int): Flow<List<OrderDetails>>

    @Query("SELECT * FROM orders WHERE id = :id")
    fun observeById(id: Long): Flow<OrderWithItems?>

    @Query("SELECT * FROM orders WHERE customerId = :customerId ORDER BY createdAt DESC")
    fun observeByCustomer(customerId: Long): Flow<List<OrderWithItems>>

    @Query("SELECT * FROM orders WHERE createdAt BETWEEN :start AND :end")
    fun observeBetween(start: Long, end: Long): Flow<List<OrderWithItems>>

    // ---------- آمار / شاخص‌ها ----------

    @Query("SELECT COUNT(*) FROM orders WHERE status IN ('NEW', 'PREPARING', 'SENT')")
    fun observeOpenOrders(): Flow<Int>

    @Query("SELECT COUNT(*) FROM orders WHERE status NOT IN ('CANCELLED')")
    fun observeActiveOrders(): Flow<Int>

    /** جمع فروش (تومان) در بازه زمانی — بدون سفارش‌های لغو شده */
    @Query(
        "SELECT COALESCE(SUM(oi.quantity * oi.sellPrice), 0) " +
            "FROM order_items oi " +
            "INNER JOIN orders o ON o.id = oi.orderId " +
            "WHERE o.createdAt BETWEEN :start AND :end AND o.status != 'CANCELLED'"
    )
    fun observeSalesBetween(start: Long, end: Long): Flow<Long>

    /** جمع سود (تومان) در بازه زمانی — بدون سفارش‌های لغو شده */
    @Query(
        "SELECT COALESCE(SUM(oi.quantity * (oi.sellPrice - oi.buyPrice)), 0) " +
            "FROM order_items oi " +
            "INNER JOIN orders o ON o.id = oi.orderId " +
            "WHERE o.createdAt BETWEEN :start AND :end AND o.status != 'CANCELLED'"
    )
    fun observeProfitBetween(start: Long, end: Long): Flow<Long>

    // ---------- نوشتن ----------

    @Insert
    suspend fun insert(order: Order): Long

    @Update
    suspend fun update(order: Order)

    @Delete
    suspend fun delete(order: Order)

    // کمک‌کننده برای تغییر وضعیت
    @Query("UPDATE orders SET status = :status WHERE id = :id")
    suspend fun updateStatus(id: Long, status: OrderStatus)
}
