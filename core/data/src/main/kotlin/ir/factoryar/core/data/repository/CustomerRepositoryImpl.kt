package ir.factoryar.core.data.repository

import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.database.dao.CustomerDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.CustomerLedger
import ir.factoryar.core.domain.model.CustomerWithBalance
import ir.factoryar.core.domain.repository.CustomerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CustomerRepositoryImpl @Inject constructor(
    private val customerDao: CustomerDao,
    private val invoiceDao: InvoiceDao,
) : CustomerRepository {

    override fun observeCustomers(query: String): Flow<List<CustomerWithBalance>> {
        val customersFlow = if (query.isBlank()) customerDao.observeAll() else customerDao.search(query)
        return combine(
            customersFlow,
            customerDao.observeBalances(DateUtils.now()),
        ) { list, balances ->
            val balanceMap = balances.associateBy { it.customerId }
            list.map { entity ->
                val b = balanceMap[entity.id]
                CustomerWithBalance(
                    customer = entity.toDomain(),
                    totalDebt = b?.totalDebt ?: 0,
                    invoiceCount = b?.invoiceCount ?: 0,
                    lastPurchaseAt = b?.lastPurchaseAt,
                    hasOverdue = b?.hasOverdue ?: false,
                )
            }
        }
    }

    override fun observeLedger(customerId: Long): Flow<CustomerLedger?> =
        combine(
            customerDao.observeById(customerId),
            invoiceDao.observeAll(),
        ) { entity, invoices ->
            entity ?: return@combine null
            val mine = invoices.filter { it.type == "SALE" && it.customerId == customerId }
            CustomerLedger(
                customer = entity.toDomain(),
                invoices = mine.map { it.toDomain() },
                totalSales = mine.sumOf { it.grandTotal },
                totalPaid = mine.sumOf { it.paidAmount },
                totalDebt = mine.sumOf { (it.grandTotal - it.paidAmount).coerceAtLeast(0) },
            )
        }

    override suspend fun getCustomer(id: Long): Customer? = customerDao.getById(id)?.toDomain()

    override suspend fun saveCustomer(customer: Customer): Long {
        val withCreated = if (customer.createdAt == 0L) customer.copy(createdAt = DateUtils.now()) else customer
        return customerDao.upsert(withCreated.toEntity())
    }

    override suspend fun deleteCustomer(id: Long) = customerDao.deleteById(id)
}
