package ir.factoryar.core.domain.repository

import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.CustomerBalanceRow
import ir.factoryar.core.domain.model.CustomerLedger
import ir.factoryar.core.domain.model.CustomerWithBalance
import ir.factoryar.core.domain.model.DashboardSummary
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.RecurringInvoice
import ir.factoryar.core.domain.model.SalesReport
import kotlinx.coroutines.flow.Flow

interface CustomerRepository {
    fun observeCustomers(query: String = ""): Flow<List<CustomerWithBalance>>
    fun observeLedger(customerId: Long): Flow<CustomerLedger?>
    suspend fun getCustomer(id: Long): Customer?
    suspend fun saveCustomer(customer: Customer): Long
    suspend fun deleteCustomer(id: Long)
}

interface InvoiceRepository {
    fun observeInvoices(
        type: InvoiceType? = null,
        status: PaymentStatus? = null,
        query: String = "",
        overdueOnly: Boolean = false,
    ): Flow<List<InvoiceWithDetails>>

    fun observeInvoice(id: Long): Flow<InvoiceWithDetails?>
    suspend fun getInvoice(id: Long): InvoiceWithDetails?

    /**
     * ذخیره فاکتور؛ اگر number خالی باشد، شماره بعدی به‌صورت خودکار تولید می‌شود.
     * @return id فاکتور ذخیره‌شده
     */
    suspend fun saveInvoice(details: InvoiceWithDetails): Long

    suspend fun deleteInvoice(id: Long)
    suspend fun setPayment(invoiceId: Long, status: PaymentStatus, paidAmount: Long)
    suspend fun previewNextNumber(type: InvoiceType): String

    fun observeDashboardSummary(): Flow<DashboardSummary>
    suspend fun buildSalesReport(from: Long, to: Long): SalesReport
    fun observeCustomerBalances(): Flow<Map<Long, CustomerBalanceRow>>
}

interface RecurringRepository {
    fun observeAll(): Flow<List<RecurringInvoice>>
    suspend fun save(recurring: RecurringInvoice): Long
    suspend fun delete(id: Long)
    suspend fun setActive(id: Long, active: Boolean)
    /** Worker روزانه: فاکتورهای سررسید را می‌سازد و nextRun را جلو می‌برد. @return تعداد فاکتورهای ساخته‌شده */
    suspend fun generateDueInvoices(nowMillis: Long): Int
}

interface BusinessRepository {
    fun observeActiveProfile(): Flow<BusinessProfile?>
    fun observeAll(): Flow<List<BusinessProfile>>
    suspend fun getActiveProfile(): BusinessProfile
    suspend fun save(profile: BusinessProfile): Long
    suspend fun setActive(id: Long)
}

interface PremiumRepository {
    val isPremium: Flow<Boolean>
    suspend fun setPremium(value: Boolean)
}

interface BackupRepository {
    /** خروجی ZIP از دیتابیس + فایل‌ها در مسیر دلخواه کاربر (SAF) */
    suspend fun exportLocalBackup(targetUriString: String): Result<String>
    suspend fun importLocalBackup(sourceUriString: String): Result<Unit>
}
