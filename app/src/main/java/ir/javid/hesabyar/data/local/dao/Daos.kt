package ir.javid.hesabyar.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import ir.javid.hesabyar.data.local.entity.*
import kotlinx.coroutines.flow.Flow

@Dao
interface SettingsDao {
    @Query("SELECT * FROM app_settings WHERE id = 1") fun observe(): Flow<AppSettingsEntity?>
    @Query("SELECT * FROM app_settings WHERE id = 1") suspend fun get(): AppSettingsEntity?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun save(settings: AppSettingsEntity)
    @Query("SELECT * FROM licenses WHERE id = 1") fun observeLicense(): Flow<LicenseEntity?>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun saveLicense(license: LicenseEntity)
}

@Dao
interface ProductDao {
    @Query("SELECT * FROM product_categories ORDER BY name") fun observeCategories(): Flow<List<ProductCategoryEntity>>
    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insertCategory(category: ProductCategoryEntity): Long
    @Update suspend fun updateCategory(category: ProductCategoryEntity)
    @Delete suspend fun deleteCategory(category: ProductCategoryEntity)

    @Query("SELECT * FROM products WHERE isActive = 1 ORDER BY name") fun observeAll(): Flow<List<ProductEntity>>
    @Query("SELECT * FROM products WHERE isActive = 1 AND (name LIKE '%' || :query || '%' OR IFNULL(sku, '') LIKE '%' || :query || '%') ORDER BY name") fun search(query: String): Flow<List<ProductEntity>>
    @Query("SELECT * FROM products WHERE id = :id") suspend fun getById(id: Long): ProductEntity?
    @Query("SELECT * FROM products WHERE isActive = 1 AND trackInventory = 1 AND stock <= minimumStock ORDER BY stock") fun observeLowStock(): Flow<List<ProductEntity>>
    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insert(product: ProductEntity): Long
    @Update suspend fun update(product: ProductEntity)
    @Query("UPDATE products SET isActive = 0, updatedAt = :updatedAt WHERE id = :id") suspend fun archive(id: Long, updatedAt: Long = System.currentTimeMillis())
    @Query("UPDATE products SET stock = stock + :delta, updatedAt = :updatedAt WHERE id = :id") suspend fun updateStock(id: Long, delta: Double, updatedAt: Long = System.currentTimeMillis())

    @Insert suspend fun insertInventoryTransaction(transaction: InventoryTransactionEntity): Long
    @Query("SELECT * FROM inventory_transactions WHERE productId = :productId ORDER BY dateEpochDay DESC, id DESC") fun observeInventory(productId: Long): Flow<List<InventoryTransactionEntity>>
}

@Dao
interface PartyDao {
    @Query("SELECT * FROM parties WHERE isActive = 1 ORDER BY name") fun observeAll(): Flow<List<PartyEntity>>
    @Query("SELECT * FROM parties WHERE isActive = 1 AND type = :type ORDER BY name") fun observeByType(type: String): Flow<List<PartyEntity>>
    @Query("SELECT * FROM parties WHERE id = :id") suspend fun getById(id: Long): PartyEntity?
    @Query("SELECT * FROM parties WHERE isActive = 1 AND name LIKE '%' || :query || '%' ORDER BY name") fun search(query: String): Flow<List<PartyEntity>>
    @Query("SELECT * FROM parties WHERE balance > 0 ORDER BY balance DESC") fun observeDebtors(): Flow<List<PartyEntity>>
    @Query("SELECT * FROM parties WHERE balance < 0 ORDER BY balance") fun observeCreditors(): Flow<List<PartyEntity>>
    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insert(party: PartyEntity): Long
    @Update suspend fun update(party: PartyEntity)
    @Query("UPDATE parties SET isActive = 0, updatedAt = :updatedAt WHERE id = :id") suspend fun archive(id: Long, updatedAt: Long = System.currentTimeMillis())
    @Query("UPDATE parties SET balance = balance + :delta, updatedAt = :updatedAt WHERE id = :id") suspend fun updateBalance(id: Long, delta: Long, updatedAt: Long = System.currentTimeMillis())
    @Insert suspend fun insertTransaction(transaction: PartyTransactionEntity): Long
    @Query("SELECT * FROM party_transactions WHERE partyId = :partyId ORDER BY dateEpochDay DESC, id DESC") fun observeTransactions(partyId: Long): Flow<List<PartyTransactionEntity>>
}

data class InvoiceListItem(
    val id: Long,
    val invoiceNumber: String,
    val partyId: Long?,
    val partyName: String?,
    val dateEpochDay: Long,
    val totalAmount: Long,
    val paidAmount: Long,
    val balanceAmount: Long,
    val status: String
)

@Dao
interface SalesDao {
    @Query("""SELECT s.id, s.invoiceNumber, s.partyId, p.name AS partyName, s.dateEpochDay, s.totalAmount, s.paidAmount, s.balanceAmount, s.status
        FROM sales_invoices s LEFT JOIN parties p ON p.id = s.partyId ORDER BY s.dateEpochDay DESC, s.id DESC""")
    fun observeInvoices(): Flow<List<InvoiceListItem>>
    @Query("SELECT * FROM sales_invoices WHERE id = :id") suspend fun getInvoice(id: Long): SalesInvoiceEntity?
    @Query("SELECT * FROM sales_invoice_items WHERE invoiceId = :invoiceId") suspend fun getItems(invoiceId: Long): List<SalesInvoiceItemEntity>
    @Query("SELECT COUNT(*) FROM sales_invoices WHERE dateEpochDay = :day") suspend fun countForDay(day: Long): Int
    @Insert suspend fun insertInvoice(invoice: SalesInvoiceEntity): Long
    @Insert suspend fun insertItems(items: List<SalesInvoiceItemEntity>)
    @Update suspend fun updateInvoice(invoice: SalesInvoiceEntity)
    @Query("UPDATE sales_invoices SET status = 'CANCELLED', updatedAt = :updatedAt WHERE id = :id") suspend fun cancel(id: Long, updatedAt: Long = System.currentTimeMillis())
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM sales_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun observeTotalForDay(day: Long): Flow<Long>
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM sales_invoices WHERE dateEpochDay BETWEEN :from AND :to AND status = 'FINAL'") fun observeTotalBetween(from: Long, to: Long): Flow<Long>
    @Query("SELECT COALESCE(SUM(totalAmount - taxAmount), 0) FROM sales_invoices WHERE dateEpochDay BETWEEN :from AND :to AND status = 'FINAL'") fun observeNetTotalBetween(from: Long, to: Long): Flow<Long>
    @Query("SELECT COUNT(*) FROM sales_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun observeCountForDay(day: Long): Flow<Int>
}

@Dao
interface PurchaseDao {
    @Query("""SELECT s.id, s.invoiceNumber, s.partyId, p.name AS partyName, s.dateEpochDay, s.totalAmount, s.paidAmount, s.balanceAmount, s.status
        FROM purchase_invoices s LEFT JOIN parties p ON p.id = s.partyId ORDER BY s.dateEpochDay DESC, s.id DESC""")
    fun observeInvoices(): Flow<List<InvoiceListItem>>
    @Query("SELECT * FROM purchase_invoices WHERE id = :id") suspend fun getInvoice(id: Long): PurchaseInvoiceEntity?
    @Query("SELECT * FROM purchase_invoice_items WHERE invoiceId = :invoiceId") suspend fun getItems(invoiceId: Long): List<PurchaseInvoiceItemEntity>
    @Query("SELECT COUNT(*) FROM purchase_invoices WHERE dateEpochDay = :day") suspend fun countForDay(day: Long): Int
    @Insert suspend fun insertInvoice(invoice: PurchaseInvoiceEntity): Long
    @Insert suspend fun insertItems(items: List<PurchaseInvoiceItemEntity>)
    @Update suspend fun updateInvoice(invoice: PurchaseInvoiceEntity)
    @Query("UPDATE purchase_invoices SET status = 'CANCELLED', updatedAt = :updatedAt WHERE id = :id") suspend fun cancel(id: Long, updatedAt: Long = System.currentTimeMillis())
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM purchase_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun observeTotalForDay(day: Long): Flow<Long>
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM purchase_invoices WHERE dateEpochDay BETWEEN :from AND :to AND status = 'FINAL'") fun observeTotalBetween(from: Long, to: Long): Flow<Long>
}

@Dao
interface CashDao {
    @Query("SELECT * FROM cash_accounts WHERE isActive = 1 ORDER BY type, name") fun observeAccounts(): Flow<List<CashAccountEntity>>
    @Query("SELECT * FROM cash_accounts WHERE id = :id") suspend fun getAccount(id: Long): CashAccountEntity?
    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insertAccount(account: CashAccountEntity): Long
    @Update suspend fun updateAccount(account: CashAccountEntity)
    @Query("UPDATE cash_accounts SET balance = balance + :delta, updatedAt = :updatedAt WHERE id = :id") suspend fun updateBalance(id: Long, delta: Long, updatedAt: Long = System.currentTimeMillis())
    @Query("SELECT COALESCE(SUM(balance), 0) FROM cash_accounts WHERE type = 'CASH' AND isActive = 1") fun observeCashBalance(): Flow<Long>
    @Query("SELECT COALESCE(SUM(balance), 0) FROM cash_accounts WHERE type = 'BANK' AND isActive = 1") fun observeBankBalance(): Flow<Long>

    @Insert suspend fun insertReceipt(receipt: ReceiptEntity): Long
    @Insert suspend fun insertPayment(payment: PaymentEntity): Long
    @Insert suspend fun insertExpense(expense: ExpenseEntity): Long
    @Insert suspend fun insertIncome(income: IncomeEntity): Long
    @Insert suspend fun insertTransfer(transfer: CashTransferEntity): Long
    @Query("SELECT * FROM receipts ORDER BY dateEpochDay DESC, id DESC LIMIT :limit") fun observeReceipts(limit: Int = 20): Flow<List<ReceiptEntity>>
    @Query("SELECT * FROM payments ORDER BY dateEpochDay DESC, id DESC LIMIT :limit") fun observePayments(limit: Int = 20): Flow<List<PaymentEntity>>
    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE dateEpochDay BETWEEN :from AND :to") fun observeExpenses(from: Long, to: Long): Flow<Long>
    @Query("SELECT COALESCE(SUM(amount), 0) FROM incomes WHERE dateEpochDay BETWEEN :from AND :to") fun observeIncomes(from: Long, to: Long): Flow<Long>
}

data class AccountBalanceRow(val accountId: Long, val code: String, val name: String, val type: String, val debit: Long, val credit: Long)
data class JournalListItem(val id: Long, val entryNumber: String, val dateEpochDay: Long, val description: String, val sourceType: String, val debit: Long, val credit: Long)
data class JournalLineRow(val dateEpochDay: Long, val entryNumber: String, val description: String, val debit: Long, val credit: Long)

@Dao
interface AccountingDao {
    @Query("SELECT * FROM accounts WHERE isActive = 1 ORDER BY code") fun observeAccounts(): Flow<List<AccountEntity>>
    @Query("SELECT * FROM accounts WHERE code = :code LIMIT 1") suspend fun findByCode(code: String): AccountEntity?
    @Query("SELECT * FROM accounts WHERE id = :id LIMIT 1") suspend fun getAccount(id: Long): AccountEntity?
    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insertAccount(account: AccountEntity): Long
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertAccounts(accounts: List<AccountEntity>)
    @Update suspend fun updateAccount(account: AccountEntity)
    @Delete suspend fun deleteAccount(account: AccountEntity)

    @Insert suspend fun insertEntry(entry: JournalEntryEntity): Long
    @Insert suspend fun insertItems(items: List<JournalItemEntity>)
    @Query("SELECT COUNT(*) FROM journal_entries WHERE dateEpochDay = :day") suspend fun countForDay(day: Long): Int
    @Query("""SELECT e.id, e.entryNumber, e.dateEpochDay, e.description, e.sourceType,
        COALESCE(SUM(i.debit), 0) AS debit, COALESCE(SUM(i.credit), 0) AS credit
        FROM journal_entries e LEFT JOIN journal_items i ON i.journalEntryId = e.id
        GROUP BY e.id ORDER BY e.dateEpochDay DESC, e.id DESC""")
    fun observeEntries(): Flow<List<JournalListItem>>
    @Query("SELECT * FROM journal_entries WHERE id = :id") suspend fun getEntry(id: Long): JournalEntryEntity?
    @Query("SELECT * FROM journal_items WHERE journalEntryId = :entryId") suspend fun getItems(entryId: Long): List<JournalItemEntity>
    @Query("DELETE FROM journal_entries WHERE id = :id AND sourceType = 'MANUAL'") suspend fun deleteManualEntry(id: Long)
    @Query("""SELECT a.id AS accountId, a.code, a.name, a.type, COALESCE(SUM(i.debit), 0) AS debit, COALESCE(SUM(i.credit), 0) AS credit
        FROM accounts a LEFT JOIN journal_items i ON i.accountId = a.id
        GROUP BY a.id ORDER BY a.code""")
    fun observeTrialBalance(): Flow<List<AccountBalanceRow>>
    @Query("""SELECT e.dateEpochDay, e.entryNumber, e.description, i.debit, i.credit
        FROM journal_items i JOIN journal_entries e ON e.id = i.journalEntryId
        WHERE i.accountId = :accountId AND e.dateEpochDay BETWEEN :from AND :to
        ORDER BY e.dateEpochDay, e.id""")
    fun observeLedger(accountId: Long, from: Long, to: Long): Flow<List<JournalLineRow>>
}

@Dao
interface ReportsDao {
    @Query("""SELECT COALESCE(SUM(CAST(i.unitCost * i.quantity AS INTEGER)), 0) FROM sales_invoice_items i
        JOIN sales_invoices s ON s.id = i.invoiceId
        WHERE s.dateEpochDay BETWEEN :from AND :to AND s.status = 'FINAL'""")
    fun observeCostOfGoods(from: Long, to: Long): Flow<Long>
}

@Dao
interface DashboardDao {
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM sales_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun salesToday(day: Long): Flow<Long>
    @Query("SELECT COALESCE(SUM(totalAmount), 0) FROM purchase_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun purchasesToday(day: Long): Flow<Long>
    @Query("""SELECT
        (SELECT COALESCE(SUM(totalAmount - taxAmount), 0) FROM sales_invoices WHERE dateEpochDay = :day AND status = 'FINAL') -
        (SELECT COALESCE(SUM(CAST(i.unitCost * i.quantity AS INTEGER)), 0) FROM sales_invoice_items i
         JOIN sales_invoices s ON s.id = i.invoiceId WHERE s.dateEpochDay = :day AND s.status = 'FINAL')
        """) fun profitToday(day: Long): Flow<Long>
    @Query("SELECT COUNT(*) FROM sales_invoices WHERE dateEpochDay = :day AND status = 'FINAL'") fun invoiceCountToday(day: Long): Flow<Int>
    @Query("SELECT COUNT(*) FROM products WHERE isActive = 1 AND trackInventory = 1 AND stock <= minimumStock") fun lowStockCount(): Flow<Int>
    @Query("SELECT COALESCE(SUM(balance), 0) FROM parties WHERE balance > 0 AND isActive = 1") fun debtorsTotal(): Flow<Long>
    @Query("SELECT COALESCE(SUM(-balance), 0) FROM parties WHERE balance < 0 AND isActive = 1") fun creditorsTotal(): Flow<Long>
}
