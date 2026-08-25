package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.SupplierEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CustomerDao {
    @Insert
    suspend fun insert(customer: CustomerEntity): Long

    @Update
    suspend fun update(customer: CustomerEntity)

    @Query("SELECT * FROM customers ORDER BY name ASC")
    fun observeAll(): Flow<List<CustomerEntity>>

    @Query("SELECT * FROM customers WHERE id = :id")
    suspend fun getById(id: Long): CustomerEntity?

    @Query("SELECT * FROM customers WHERE id = :id")
    fun observeById(id: Long): Flow<CustomerEntity?>

    @Query("SELECT * FROM customers WHERE name LIKE '%' || :query || '%' OR mobile LIKE '%' || :query || '%' ORDER BY name ASC LIMIT 30")
    fun observeSearch(query: String): Flow<List<CustomerEntity>>

    @Query("SELECT COUNT(*) FROM customers")
    fun observeCount(): Flow<Int>

    /**
     * Phase 4.1: the customer's current outstanding credit («بستانکی»),
     * computed EXACTLY from the financial state instead of incrementally:
     * non-cash order totals (same Rubi total rule as [com.modir.forushgah.data.repository.OrderRepository])
     * minus payments, plus refunds, minus revenue reversed by active returns.
     * Terminal orders (CANCELLED / DELETED) are excluded. The caller applies
     * the non-negative policy.
     */
    @Query(
        """
        SELECT
          COALESCE((SELECT COALESCE(SUM(oi.unitSellingPrice * oi.quantity - oi.discount), 0) - o.discount
                     + CASE WHEN o.shippingPaymentType = 'CUSTOMER_PREPAID' THEN o.shippingChargedToCustomer ELSE 0 END
               FROM orders o
               LEFT JOIN order_items oi ON oi.orderId = o.id
               WHERE o.customerId = :customerId AND o.isCashPayment = 0
                 AND o.status NOT IN ('CANCELLED', 'DELETED')), 0)
          - COALESCE((SELECT COALESCE(SUM(p.amount), 0)
                 FROM payments p
                 JOIN orders o2 ON o2.id = p.orderId
                 WHERE o2.customerId = :customerId AND o2.isCashPayment = 0
                   AND o2.status NOT IN ('CANCELLED', 'DELETED')), 0)
          + COALESCE((SELECT COALESCE(SUM(r.amount), 0)
                 FROM refunds r
                 JOIN orders o3 ON o3.id = r.orderId
                 WHERE o3.customerId = :customerId AND o3.isCashPayment = 0
                   AND o3.status NOT IN ('CANCELLED', 'DELETED')), 0)
          - COALESCE((SELECT COALESCE(SUM(rt.revenueReversed), 0)
                 FROM order_returns rt
                 JOIN orders o4 ON o4.id = rt.orderId
                 WHERE o4.customerId = :customerId AND o4.isCashPayment = 0
                   AND o4.status NOT IN ('CANCELLED', 'DELETED')
                   AND rt.status != 'REJECTED'), 0)
        """,
    )
    suspend fun sumActiveCredit(customerId: Long): Long
}

@Dao
interface SupplierDao {
    @Insert
    suspend fun insert(supplier: SupplierEntity): Long

    @Update
    suspend fun update(supplier: SupplierEntity)

    @Query("UPDATE suppliers SET isActive = 0, updatedAt = :now WHERE id = :supplierId")
    suspend fun archive(supplierId: Long, now: Long)

    @Query("SELECT * FROM suppliers WHERE isActive = 1 ORDER BY name ASC")
    fun observeAll(): Flow<List<SupplierEntity>>

    @Query("SELECT * FROM suppliers WHERE id = :id")
    suspend fun getById(id: Long): SupplierEntity?

    @Query("SELECT * FROM suppliers WHERE id = :id")
    fun observeById(id: Long): Flow<SupplierEntity?>

    @Query("SELECT * FROM suppliers WHERE isActive = 1 AND name LIKE '%' || :query || '%' ORDER BY name ASC LIMIT 30")
    fun observeSearch(query: String): Flow<List<SupplierEntity>>
}
