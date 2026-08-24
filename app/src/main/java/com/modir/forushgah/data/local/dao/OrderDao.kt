package com.modir.forushgah.data.local.dao

import androidx.room.*
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.entity.OrderEntity
import com.modir.forushgah.data.local.entity.OrderItemEntity
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ShippingPaymentType
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

    @Query("SELECT * FROM orders WHERE id = :id")
    fun observeById(id: Long): Flow<OrderEntity?>

    @Query("SELECT * FROM order_items WHERE orderId = :orderId")
    suspend fun getItems(orderId: Long): List<OrderItemEntity>

    @Query(
        """
        SELECT oi.*, COALESCE(p.name, oi.title) AS productName
        FROM order_items oi
        LEFT JOIN products p ON p.id = oi.productId
        WHERE oi.orderId = :orderId
        """,
    )
    suspend fun getItemsWithProduct(orderId: Long): List<OrderItemWithProduct>

    /** Next Rubi-style sequential invoice number: max numeric + 1. */
    @Query("SELECT COALESCE(MAX(CASE WHEN orderNumber GLOB '[0-9]*' THEN CAST(orderNumber AS INTEGER) ELSE 0 END), 0) + 1 FROM orders")
    suspend fun nextOrderNumber(): Int

    /** Phase 3.1 (Rubi list action): hard delete — items/payments/refunds/
     * returns cascade via FK. Callers must restore stock beforehand. */
    @Query("DELETE FROM orders WHERE id = :id")
    suspend fun deleteOrder(id: Long)

    /** List rows join the customer and pre-aggregate paid/line totals in SQL
     * (no N+1 in the UI). `paidAmount`/`itemsTotal` are denormalized sums. */
    @Query(
        """
        SELECT o.*, c.name AS customerName, c.mobile AS customerMobile,
               s.name AS supplierName,
               pm.name AS paymentMethodName,
               (SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.orderId = o.id) AS paidAmount,
               (SELECT COALESCE(SUM(oi.unitSellingPrice * oi.quantity - oi.discount), 0)
                  FROM order_items oi WHERE oi.orderId = o.id) AS itemsTotal,
               (SELECT COUNT(*) FROM order_items oi2 WHERE oi2.orderId = o.id) AS itemCount
        FROM orders o
        LEFT JOIN customers c ON c.id = o.customerId
        LEFT JOIN suppliers s ON s.id = o.supplierId
        LEFT JOIN payment_methods pm ON pm.id = o.paymentMethodId
        ORDER BY o.orderDate DESC
        """,
    )
    fun observeAllWithCustomer(): Flow<List<OrderWithCustomer>>

    @Query(
        """
        SELECT o.*, c.name AS customerName, c.mobile AS customerMobile,
               s.name AS supplierName,
               pm.name AS paymentMethodName,
               (SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.orderId = o.id) AS paidAmount,
               (SELECT COALESCE(SUM(oi.unitSellingPrice * oi.quantity - oi.discount), 0)
                  FROM order_items oi WHERE oi.orderId = o.id) AS itemsTotal,
               (SELECT COUNT(*) FROM order_items oi2 WHERE oi2.orderId = o.id) AS itemCount
        FROM orders o
        LEFT JOIN customers c ON c.id = o.customerId
        LEFT JOIN suppliers s ON s.id = o.supplierId
        LEFT JOIN payment_methods pm ON pm.id = o.paymentMethodId
        WHERE o.status = :status
        ORDER BY o.orderDate DESC
        """,
    )
    fun observeByStatusWithCustomer(status: OrderStatus): Flow<List<OrderWithCustomer>>

    /** Spec §16: search by order number, customer name or customer mobile. */
    @Query(
        """
        SELECT o.*, c.name AS customerName, c.mobile AS customerMobile,
               s.name AS supplierName,
               pm.name AS paymentMethodName,
               (SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.orderId = o.id) AS paidAmount,
               (SELECT COALESCE(SUM(oi.unitSellingPrice * oi.quantity - oi.discount), 0)
                  FROM order_items oi WHERE oi.orderId = o.id) AS itemsTotal,
               (SELECT COUNT(*) FROM order_items oi2 WHERE oi2.orderId = o.id) AS itemCount
        FROM orders o
        LEFT JOIN customers c ON c.id = o.customerId
        LEFT JOIN suppliers s ON s.id = o.supplierId
        LEFT JOIN payment_methods pm ON pm.id = o.paymentMethodId
        WHERE o.orderNumber LIKE '%' || :query || '%'
           OR c.name LIKE '%' || :query || '%'
           OR c.mobile LIKE '%' || :query || '%'
        ORDER BY o.orderDate DESC
        """,
    )
    fun observeSearchWithCustomer(query: String): Flow<List<OrderWithCustomer>>

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY orderDate DESC")
    fun observeByStatus(status: OrderStatus): Flow<List<OrderEntity>>

    @Query("SELECT COUNT(*) FROM orders WHERE orderDate BETWEEN :startOfDay AND :endOfDay")
    fun observeTodayOrderCount(startOfDay: Long, endOfDay: Long): Flow<Int>

    @Query("SELECT COUNT(*) FROM orders WHERE status IN ('NEW','CONFIRMED','PREPARING')")
    fun observePendingOrderCount(): Flow<Int>
}

/** Order line with the product name joined in (free lines fall back to their
 * own title snapshot — spec §17 product section). */
data class OrderItemWithProduct(
    @Embedded val item: OrderItemEntity,
    val productName: String,
)

/** One row of the order list (spec §15): order + customer + live sums. */
data class OrderWithCustomer(
    @Embedded val order: OrderEntity,
    val customerName: String?,
    val customerMobile: String?,
    val supplierName: String?,
    val paymentMethodName: String?,
    val paidAmount: Long,
    val itemsTotal: Long,
    val itemCount: Int,
) {
    /** Same rule as `Order.totalCustomerPayment`, from denormalized sums. */
    val totalCustomerPayment: Money
        get() {
            val subtotal = Money(itemsTotal) - order.discount
            val shipping =
                if (order.shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) order.shippingChargedToCustomer
                else Money.ZERO
            return subtotal + shipping
        }

    val isFullyPaid: Boolean get() = paidAmount >= totalCustomerPayment.amountInToman
}
