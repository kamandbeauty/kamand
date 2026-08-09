package ir.factoryar.core.data.repository

import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.database.dao.CustomerDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.domain.model.DebtorsSummary
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.repository.DebtorRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DebtorRepositoryImpl @Inject constructor(
    private val invoiceDao: InvoiceDao,
    private val customerDao: CustomerDao,
) : DebtorRepository {

    override fun observeDebtors(sort: DebtorSort, onlyOverdue: Boolean): Flow<DebtorsSummary> =
        combine(invoiceDao.observeOpenReceivables(), customerDao.observeAll()) { invoices, customers ->
            build(
                invoices = invoices.map { it.toDomain() },
                customers = customers.map { it.toDomain() },
                sort = sort,
                onlyOverdue = onlyOverdue,
            )
        }

    override suspend fun getDebtors(sort: DebtorSort, onlyOverdue: Boolean): DebtorsSummary = build(
        invoices = invoiceDao.getOpenReceivables().map { it.toDomain() },
        customers = customerDao.observeAll().first().map { it.toDomain() },
        sort = sort,
        onlyOverdue = onlyOverdue,
    )

    override suspend fun getDebtor(customerId: Long): DebtorEntry? =
        getDebtors(DebtorSort.AMOUNT, onlyOverdue = false).debtors.firstOrNull { it.customer.id == customerId }

    private fun build(
        invoices: List<Invoice>,
        customers: List<Customer>,
        sort: DebtorSort,
        onlyOverdue: Boolean,
    ): DebtorsSummary {
        val now = DateUtils.now()
        val customerById = customers.associateBy { it.id }

        val entries = invoices
            .filter { it.customerId != null && it.remainingAmount > 0 }
            .groupBy { it.customerId!! }
            .mapNotNull { (customerId, list) ->
                val customer = customerById[customerId] ?: return@mapNotNull null
                val overdue = list.filter { it.dueDate != null && it.dueDate < now }
                val maxDays = overdue.maxOfOrNull { inv ->
                    ((now - (inv.dueDate ?: now)) / DateUtils.DAY_MILLIS).toInt()
                } ?: 0
                DebtorEntry(
                    customer = customer,
                    totalDebt = list.sumOf { it.remainingAmount },
                    overdueAmount = overdue.sumOf { it.remainingAmount },
                    overdueInvoiceCount = overdue.size,
                    maxOverdueDays = maxDays,
                    lastPurchaseAt = list.maxOfOrNull { it.issueDate },
                    overdueInvoices = overdue.sortedBy { it.dueDate },
                )
            }
            .filter { !onlyOverdue || it.hasOverdue }

        val sorted = when (sort) {
            DebtorSort.AMOUNT -> entries.sortedByDescending { it.totalDebt }
            DebtorSort.OVERDUE_DAYS -> entries.sortedWith(
                compareByDescending<DebtorEntry> { it.maxOverdueDays }.thenByDescending { it.totalDebt },
            )
            DebtorSort.NAME -> entries.sortedBy { it.customer.name }
        }

        return DebtorsSummary(
            debtors = sorted,
            totalDebt = sorted.sumOf { it.totalDebt },
            totalOverdue = sorted.sumOf { it.overdueAmount },
            overdueCustomerCount = sorted.count { it.hasOverdue },
        )
    }
}
