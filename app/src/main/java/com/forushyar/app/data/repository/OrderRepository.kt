package com.forushyar.app.data.repository

import androidx.room.withTransaction
import com.forushyar.app.data.local.AppDatabase
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.dao.OrderItemDao
import com.forushyar.app.data.local.entity.Order
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.data.local.entity.OrderItem
import com.forushyar.app.data.local.entity.OrderStatus
import com.forushyar.app.data.local.entity.OrderWithItems
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OrderRepository @Inject constructor(
    private val database: AppDatabase,
    private val orderDao: OrderDao,
    private val orderItemDao: OrderItemDao
) {
    fun observeAll(): Flow<List<OrderDetails>> = orderDao.observeAll()

    fun observeRecent(limit: Int): Flow<List<OrderDetails>> = orderDao.observeRecent(limit)

    fun observeById(id: Long): Flow<OrderDetails?> = orderDao.observeById(id)

    fun observeByCustomer(customerId: Long): Flow<List<OrderWithItems>> =
        orderDao.observeByCustomer(customerId)

    /**
     * ثبت سفارش به همراه اقلام آن در یک عملیات.
     */
    suspend fun createOrder(customerId: Long, note: String, items: List<OrderItem>): Long =
        database.withTransaction {
            val orderId = orderDao.insert(Order(customerId = customerId, note = note))
            orderItemDao.insertAll(items.map { it.copy(orderId = orderId) })
            orderId
        }

    suspend fun updateStatus(orderId: Long, status: OrderStatus) =
        orderDao.updateStatus(orderId, status)

    suspend fun update(order: Order) = orderDao.update(order)

    suspend fun delete(order: Order) = orderDao.delete(order)

    /** حذف سفارش؛ اقلام به‌کمک کلید خارجی به‌صورت زنجیره‌ای حذف می‌شوند. */
    suspend fun deleteById(orderId: Long) = orderDao.deleteById(orderId)
}
