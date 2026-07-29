package ir.factoryar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import ir.factoryar.core.database.entity.CustomerEntity
import kotlinx.coroutines.flow.Flow

data class CustomerBalanceDbRow(
    val customerId: Long,
    val totalDebt: Long,
    val invoiceCount: Int,
    val lastPurchaseAt: Long?,
    val hasOverdue: Boolean,
)

@Dao
interface CustomerDao {

    @Query("SELECT * FROM customers ORDER BY name COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<CustomerEntity>>

    @Query(
        "SELECT * FROM customers WHERE name LIKE '%' || :query || '%' OR phone LIKE '%' || :query || '%' ORDER BY name ASC"
    )
    fun search(query: String): Flow<List<CustomerEntity>>

    @Query("SELECT * FROM customers WHERE id = :id")
    fun observeById(id: Long): Flow<CustomerEntity?>

    @Query("SELECT * FROM customers WHERE id = :id")
    suspend fun getById(id: Long): CustomerEntity?

    @Query("SELECT COUNT(*) FROM customers")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(customer: CustomerEntity): Long

    @Query("DELETE FROM customers WHERE id = :id")
    suspend fun deleteById(id: Long)

    /** مانده بدهی هر مشتری (فقط فاکتورهای فروش تسویه‌نشده) */
    @Query(
        """
        SELECT i.customerId AS customerId,
               COALESCE(SUM(i.grandTotal - i.paidAmount), 0) AS totalDebt,
               COUNT(i.id) AS invoiceCount,
               MAX(i.issueDate) AS lastPurchaseAt,
               SUM(CASE WHEN i.dueDate IS NOT NULL AND i.dueDate < :now AND i.status != 'PAID' THEN 1 ELSE 0 END) > 0 AS hasOverdue
        FROM invoices i
        WHERE i.type = 'SALE' AND i.customerId IS NOT NULL
        GROUP BY i.customerId
        """
    )
    fun observeBalances(now: Long): Flow<List<CustomerBalanceDbRow>>

    @Query("SELECT * FROM invoices WHERE type = 'SALE' AND customerId = :customerId ORDER BY issueDate DESC")
    suspend fun salesOfCustomer(customerId: Long): List<ir.factoryar.core.database.entity.InvoiceEntity>
}
