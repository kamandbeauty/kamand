package ir.factoryar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import ir.factoryar.core.database.entity.InvoiceEntity
import ir.factoryar.core.database.entity.InvoiceItemEntity
import ir.factoryar.core.database.entity.InvoiceWithItemsEntity
import kotlinx.coroutines.flow.Flow

data class DailySalesDbRow(
    val bucket: Long,
    val total: Long,
)

/** درآمد و بهای تمام‌شده در یک بازه — مبنای سود ناخالص */
data class RevenueCostDbRow(
    val bucket: Long,
    val revenue: Long,
    val cost: Long,
)

@Dao
interface InvoiceDao {

    @Query("SELECT * FROM invoices ORDER BY issueDate DESC, id DESC")
    fun observeAll(): Flow<List<InvoiceEntity>>

    @Transaction
    @Query("SELECT * FROM invoices WHERE id = :id")
    fun observeWithItems(id: Long): Flow<InvoiceWithItemsEntity?>

    @Transaction
    @Query("SELECT * FROM invoices WHERE id = :id")
    suspend fun getWithItems(id: Long): InvoiceWithItemsEntity?

    @Query("SELECT * FROM invoices WHERE id = :id")
    suspend fun getById(id: Long): InvoiceEntity?

    @Query("SELECT COUNT(*) FROM invoices WHERE number = :number")
    suspend fun numberExists(number: String): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertInvoice(invoice: InvoiceEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertItems(items: List<InvoiceItemEntity>): List<Long>

    @Query("DELETE FROM invoice_items WHERE invoiceId = :invoiceId")
    suspend fun deleteItemsOf(invoiceId: Long)

    @Query("DELETE FROM invoices WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("UPDATE invoices SET status = :status, paidAmount = :paidAmount, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updatePayment(id: Long, status: String, paidAmount: Long, updatedAt: Long)

    // ---------------- داشبورد ----------------

    @Query(
        "SELECT COALESCE(SUM(grandTotal), 0) FROM invoices WHERE type = 'SALE' AND issueDate >= :from AND issueDate < :to"
    )
    fun observeSumSales(from: Long, to: Long): Flow<Long>

    @Query(
        "SELECT COUNT(*) FROM invoices WHERE type = 'SALE' AND issueDate >= :from AND issueDate < :to"
    )
    fun observeCountSales(from: Long, to: Long): Flow<Int>

    @Query(
        "SELECT COALESCE(SUM(grandTotal), 0) FROM invoices WHERE type = 'PURCHASE' AND issueDate >= :from AND issueDate < :to"
    )
    fun observeSumPurchase(from: Long, to: Long): Flow<Long>

    @Query("SELECT COALESCE(SUM(grandTotal - paidAmount), 0) FROM invoices WHERE type = 'SALE' AND status != 'PAID'")
    fun observeTotalReceivable(): Flow<Long>

    @Query(
        "SELECT COUNT(*) FROM invoices WHERE type = 'SALE' AND status != 'PAID' AND dueDate IS NOT NULL AND dueDate < :now"
    )
    fun observeOverdueCount(now: Long): Flow<Int>

    @Query(
        """
        SELECT (issueDate / :dayMs) * :dayMs AS bucket, COALESCE(SUM(grandTotal), 0) AS total
        FROM invoices
        WHERE type = 'SALE' AND issueDate >= :from
        GROUP BY bucket ORDER BY bucket ASC
        """
    )
    fun observeDailySales(from: Long, dayMs: Long = 86_400_000): Flow<List<DailySalesDbRow>>

    // ---------------- گزارش بازه‌ای ----------------

    @Query("SELECT * FROM invoices WHERE issueDate >= :from AND issueDate < :to ORDER BY issueDate ASC")
    suspend fun getInRange(from: Long, to: Long): List<InvoiceEntity>

    @Transaction
    @Query("SELECT * FROM invoices WHERE issueDate >= :from AND issueDate < :to ORDER BY issueDate ASC")
    suspend fun getWithItemsInRange(from: Long, to: Long): List<InvoiceWithItemsEntity>

    @Query("SELECT * FROM invoices ORDER BY issueDate DESC LIMIT :limit")
    fun observeRecent(limit: Int = 10): Flow<List<InvoiceEntity>>

    // ---------------- سود و زیان ----------------

    /** بهای تمام‌شده کالای فروش‌رفته (COGS) در بازه */
    @Query(
        """
        SELECT COALESCE(SUM(it.quantity * it.costPrice), 0)
        FROM invoice_items it
        INNER JOIN invoices i ON i.id = it.invoiceId
        WHERE i.type = 'SALE' AND i.issueDate >= :from AND i.issueDate < :to
        """
    )
    suspend fun sumCogs(from: Long, to: Long): Long

    @Query(
        """
        SELECT COALESCE(SUM(it.quantity * it.costPrice), 0)
        FROM invoice_items it
        INNER JOIN invoices i ON i.id = it.invoiceId
        WHERE i.type = 'SALE' AND i.issueDate >= :from AND i.issueDate < :to
        """
    )
    fun observeCogs(from: Long, to: Long): Flow<Long>

    /** درآمد و بهای تمام‌شده تفکیک‌شده بر حسب سطل زمانی (روز/ماه) */
    @Query(
        """
        SELECT (i.issueDate / :bucketMs) * :bucketMs AS bucket,
               COALESCE(SUM(i.grandTotal), 0) AS revenue,
               COALESCE((
                   SELECT SUM(it.quantity * it.costPrice)
                   FROM invoice_items it WHERE it.invoiceId = i.id
               ), 0) AS cost
        FROM invoices i
        WHERE i.type = 'SALE' AND i.issueDate >= :from AND i.issueDate < :to
        GROUP BY bucket ORDER BY bucket ASC
        """
    )
    suspend fun revenueAndCostBuckets(from: Long, to: Long, bucketMs: Long): List<RevenueCostDbRow>

    /** فاکتورهای فروش تسویه‌نشده یک مشتری (برای فهرست بدهکاران) */
    @Query(
        """
        SELECT * FROM invoices
        WHERE type = 'SALE' AND status != 'PAID' AND grandTotal > paidAmount
        ORDER BY dueDate ASC
        """
    )
    fun observeOpenReceivables(): Flow<List<InvoiceEntity>>

    @Query(
        """
        SELECT * FROM invoices
        WHERE type = 'SALE' AND status != 'PAID' AND grandTotal > paidAmount
        ORDER BY dueDate ASC
        """
    )
    suspend fun getOpenReceivables(): List<InvoiceEntity>
}
