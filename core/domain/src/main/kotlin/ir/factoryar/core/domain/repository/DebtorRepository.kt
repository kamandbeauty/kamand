package ir.factoryar.core.domain.repository

import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.domain.model.DebtorsSummary
import kotlinx.coroutines.flow.Flow

interface DebtorRepository {
    /** فهرست مشتریان بدهکار به‌همراه جزئیات معوقات */
    fun observeDebtors(sort: DebtorSort = DebtorSort.AMOUNT, onlyOverdue: Boolean = false): Flow<DebtorsSummary>

    /** یک‌بار خواندن (برای Worker نوتیفیکیشن) */
    suspend fun getDebtors(sort: DebtorSort = DebtorSort.OVERDUE_DAYS, onlyOverdue: Boolean = true): DebtorsSummary

    suspend fun getDebtor(customerId: Long): DebtorEntry?
}
