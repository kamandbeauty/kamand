package ir.javid.hesabyar.domain.repository

import ir.javid.hesabyar.core.model.*
import ir.javid.hesabyar.data.local.dao.*
import ir.javid.hesabyar.data.local.entity.*
import kotlinx.coroutines.flow.Flow
import java.io.InputStream
import java.io.OutputStream

interface DashboardRepository {
    val summary: Flow<DashboardSummary>
}

interface SettingsRepository {
    val settings: Flow<AppSettingsEntity>
    val license: Flow<LicenseStatus>
    suspend fun save(settings: AppSettingsEntity)
    suspend fun activateProfessional(token: String): Result<Unit>
}

interface ProductRepository {
    val products: Flow<List<ProductEntity>>
    val categories: Flow<List<ProductCategoryEntity>>
    val lowStock: Flow<List<ProductEntity>>
    fun search(query: String): Flow<List<ProductEntity>>
    suspend fun save(product: ProductEntity): Result<Long>
    suspend fun archive(id: Long): Result<Unit>
    suspend fun saveCategory(category: ProductCategoryEntity): Result<Long>
    suspend fun deleteCategory(category: ProductCategoryEntity): Result<Unit>
    fun inventory(productId: Long): Flow<List<InventoryTransactionEntity>>
    suspend fun adjustStock(productId: Long, quantity: Double, note: String, dateEpochDay: Long): Result<Unit>
}

interface PartyRepository {
    val parties: Flow<List<PartyEntity>>
    val debtors: Flow<List<PartyEntity>>
    val creditors: Flow<List<PartyEntity>>
    fun byType(type: String): Flow<List<PartyEntity>>
    fun search(query: String): Flow<List<PartyEntity>>
    suspend fun save(party: PartyEntity): Result<Long>
    suspend fun archive(id: Long): Result<Unit>
    fun transactions(partyId: Long): Flow<List<PartyTransactionEntity>>
}

interface InvoiceRepository {
    val sales: Flow<List<InvoiceListItem>>
    val purchases: Flow<List<InvoiceListItem>>
    suspend fun createSale(input: InvoiceInput): Result<Long>
    suspend fun createPurchase(input: InvoiceInput): Result<Long>
    suspend fun cancelSale(invoiceId: Long): Result<Unit>
    suspend fun cancelPurchase(invoiceId: Long): Result<Unit>
    suspend fun invoiceDocument(kind: InvoiceKind, invoiceId: Long): InvoiceDocument?
}

interface CashRepository {
    val accounts: Flow<List<CashAccountEntity>>
    val cashBalance: Flow<Long>
    val bankBalance: Flow<Long>
    val receipts: Flow<List<ReceiptEntity>>
    val payments: Flow<List<PaymentEntity>>
    suspend fun saveAccount(account: CashAccountEntity): Result<Long>
    suspend fun receive(receipt: ReceiptEntity): Result<Long>
    suspend fun pay(payment: PaymentEntity): Result<Long>
    suspend fun addExpense(expense: ExpenseEntity): Result<Long>
    suspend fun addIncome(income: IncomeEntity): Result<Long>
    suspend fun transfer(transfer: CashTransferEntity): Result<Long>
}

interface AccountingRepository {
    val accounts: Flow<List<AccountEntity>>
    val entries: Flow<List<JournalListItem>>
    val trialBalance: Flow<List<AccountBalanceRow>>
    suspend fun saveAccount(account: AccountEntity): Result<Long>
    suspend fun saveManualEntry(input: JournalInput): Result<Long>
    suspend fun deleteManualEntry(id: Long): Result<Unit>
    fun ledger(accountId: Long, from: Long, to: Long): Flow<List<JournalLineRow>>
}

interface ReportsRepository {
    fun sales(from: Long, to: Long): Flow<Long>
    fun purchases(from: Long, to: Long): Flow<Long>
    fun expenses(from: Long, to: Long): Flow<Long>
    fun incomes(from: Long, to: Long): Flow<Long>
    fun profitLoss(from: Long, to: Long): Flow<ProfitLossSummary>
}

interface BackupRepository {
    suspend fun exportTo(output: OutputStream): Result<Unit>
    suspend fun restoreFrom(input: InputStream): Result<Unit>
}
