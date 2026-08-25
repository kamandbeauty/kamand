package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Embedded
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.modir.forushgah.data.local.entity.*
import kotlinx.coroutines.flow.Flow

@Dao
interface ReceivableDao {
    @Insert
    suspend fun insert(receivable: ReceivableEntity): Long

    @Update
    suspend fun update(receivable: ReceivableEntity)

    @Query("SELECT * FROM receivables WHERE status IN ('EXPECTED','PARTIALLY_PAID','OVERDUE') ORDER BY expectedDate ASC")
    fun observeOutstanding(): Flow<List<ReceivableEntity>>

    @Query("SELECT COALESCE(SUM(expectedAmount - receivedAmount), 0) FROM receivables WHERE status IN ('EXPECTED','PARTIALLY_PAID','OVERDUE')")
    fun observeTotalOutstanding(): Flow<Long>

    @Query("SELECT * FROM receivables WHERE status = 'OVERDUE' ORDER BY expectedDate ASC")
    fun observeOverdue(): Flow<List<ReceivableEntity>>
}

@Dao
interface PayableDao {
    @Insert
    suspend fun insert(payable: PayableEntity): Long

    @Update
    suspend fun update(payable: PayableEntity)

    @Query("SELECT * FROM payables WHERE status IN ('EXPECTED','PARTIALLY_PAID','OVERDUE') ORDER BY dueDate ASC")
    fun observeOutstanding(): Flow<List<PayableEntity>>

    @Query("SELECT COALESCE(SUM(expectedAmount - paidAmount), 0) FROM payables WHERE status IN ('EXPECTED','PARTIALLY_PAID','OVERDUE')")
    fun observeTotalOutstanding(): Flow<Long>
}

@Dao
interface SupplierPaymentDao {
    @Insert
    suspend fun insert(payment: SupplierPaymentEntity): Long

    @Query("SELECT * FROM supplier_payments WHERE supplierId = :supplierId ORDER BY paidAt DESC")
    suspend fun getForSupplier(supplierId: Long): List<SupplierPaymentEntity>
}

@Dao
interface OrderReturnDao {
    @Insert
    suspend fun insert(orderReturn: OrderReturnEntity): Long

    @Update
    suspend fun update(orderReturn: OrderReturnEntity)

    @Query("SELECT * FROM order_returns ORDER BY date DESC")
    fun observeAll(): Flow<List<OrderReturnEntity>>

    @Query("SELECT * FROM order_returns WHERE id = :id")
    fun observeById(id: Long): Flow<OrderReturnEntity?>

    @Query("SELECT * FROM order_return_items WHERE returnId = :returnId")
    suspend fun getItems(returnId: Long): List<OrderReturnItemEntity>

    @Insert
    suspend fun insertItems(items: List<OrderReturnItemEntity>)

    @Query("SELECT * FROM order_returns WHERE orderId = :orderId ORDER BY date DESC")
    fun observeForOrder(orderId: Long): Flow<List<OrderReturnEntity>>

    /** Units of [productId] already returned for this order (excluding
     * rejected returns) — used to cap partial returns (spec §21). */
    @Query(
        """
        SELECT COALESCE(SUM(ri.quantity), 0)
        FROM order_return_items ri
        JOIN order_returns r ON r.id = ri.returnId
        WHERE r.orderId = :orderId AND ri.productId = :productId AND r.status != 'REJECTED'
        """,
    )
    suspend fun sumReturnedQuantity(orderId: Long, productId: Long): Int

    /** Phase 4.1: total revenue reversed by ACTIVE (non-rejected) returns of
     * the order — used for customer credit and correction accounting. */
    @Query("SELECT COALESCE(SUM(revenueReversed), 0) FROM order_returns WHERE orderId = :orderId AND status != 'REJECTED'")
    suspend fun sumActiveReversedRevenue(orderId: Long): Long

    @Query(
        """
        SELECT r.*, o.orderNumber AS orderNumber, c.name AS customerName
        FROM order_returns r
        JOIN orders o ON o.id = r.orderId
        LEFT JOIN customers c ON c.id = o.customerId
        ORDER BY r.date DESC
        """,
    )
    fun observeAllWithOrder(): Flow<List<ReturnWithOrder>>
}

data class ReturnWithOrder(
    @Embedded val returnRow: OrderReturnEntity,
    val orderNumber: String,
    val customerName: String?,
)

@Dao
interface FinancialTransactionDao {
    @Insert
    suspend fun insert(transaction: FinancialTransactionEntity): Long

    @Query("SELECT * FROM financial_transactions WHERE date BETWEEN :start AND :end ORDER BY date DESC")
    fun observeBetween(start: Long, end: Long): Flow<List<FinancialTransactionEntity>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM financial_transactions WHERE type = 'SALE' AND date BETWEEN :start AND :end")
    fun observeSalesBetween(start: Long, end: Long): Flow<Long>

    // ---- Phase 4.1: traceability + idempotency guards -----------------------

    @Query("SELECT * FROM financial_transactions WHERE orderId = :orderId ORDER BY date ASC, id ASC")
    suspend fun getByOrder(orderId: Long): List<FinancialTransactionEntity>

    @Query("SELECT * FROM financial_transactions WHERE returnId = :returnId ORDER BY date ASC, id ASC")
    suspend fun getByReturn(returnId: Long): List<FinancialTransactionEntity>

    /** Idempotency: at most one event of [typeName] per order. */
    @Query("SELECT COUNT(*) FROM financial_transactions WHERE orderId = :orderId AND type = :typeName")
    suspend fun countByOrderAndType(orderId: Long, typeName: String): Int

    /** Idempotency: at most one event of [typeName] per payment row. */
    @Query("SELECT COUNT(*) FROM financial_transactions WHERE paymentId = :paymentId AND type = :typeName")
    suspend fun countByPaymentAndType(paymentId: Long, typeName: String): Int

    /** Idempotency: at most one event of [typeName] per refund row. */
    @Query("SELECT COUNT(*) FROM financial_transactions WHERE refundId = :refundId AND type = :typeName")
    suspend fun countByRefundAndType(refundId: Long, typeName: String): Int

    /** Idempotency: at most one event of [typeName] per return. */
    @Query("SELECT COUNT(*) FROM financial_transactions WHERE returnId = :returnId AND type = :typeName")
    suspend fun countByReturnAndType(returnId: Long, typeName: String): Int

    /** Idempotency: an event is reversed at most once (by any correction). */
    @Query("SELECT COUNT(*) FROM financial_transactions WHERE reversalOfId = :reversalOfId")
    suspend fun countReversalsOf(reversalOfId: Long): Int
}
