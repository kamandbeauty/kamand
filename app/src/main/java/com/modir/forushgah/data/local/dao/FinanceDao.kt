package com.modir.forushgah.data.local.dao

import androidx.room.Dao
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

    @Query("SELECT * FROM order_returns ORDER BY date DESC")
    fun observeAll(): Flow<List<OrderReturnEntity>>
}

@Dao
interface FinancialTransactionDao {
    @Insert
    suspend fun insert(transaction: FinancialTransactionEntity): Long

    @Query("SELECT * FROM financial_transactions WHERE date BETWEEN :start AND :end ORDER BY date DESC")
    fun observeBetween(start: Long, end: Long): Flow<List<FinancialTransactionEntity>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM financial_transactions WHERE type = 'SALE' AND date BETWEEN :start AND :end")
    fun observeSalesBetween(start: Long, end: Long): Flow<Long>
}
