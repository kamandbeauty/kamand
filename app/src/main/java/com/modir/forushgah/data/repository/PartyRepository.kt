package com.modir.forushgah.data.repository

import com.modir.forushgah.data.local.dao.CustomerDao
import com.modir.forushgah.data.local.dao.OrderDao
import com.modir.forushgah.data.local.dao.SupplierDao
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.SupplierEntity
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.domain.model.CustomerProfile
import com.modir.forushgah.domain.model.Supplier
import com.modir.forushgah.domain.model.SupplierProfile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CustomerRepository @Inject constructor(
    private val customerDao: CustomerDao,
) {
    fun observeAll(): Flow<List<Customer>> = customerDao.observeAll().map { list -> list.map { it.toDomain() } }

    fun observeSearch(query: String): Flow<List<Customer>> =
        customerDao.observeSearch(query).map { list -> list.map { it.toDomain() } }

    fun observeById(id: Long): Flow<Customer?> = customerDao.observeById(id).map { it?.toDomain() }

    suspend fun getById(id: Long): Customer? = customerDao.getById(id)?.toDomain()

    /** Used by the reusable CustomerSelector (spec §9) so an order screen can
     * create a brand-new customer inline without navigating away. */
    suspend fun quickCreate(name: String, mobile: String?): Long =
        customerDao.insert(
            CustomerEntity(
                name = name, mobile = mobile,
                createdAt = System.currentTimeMillis(), updatedAt = System.currentTimeMillis(),
            ),
        )

    suspend fun create(customer: Customer): Long = customerDao.insert(customer.toEntity())

    suspend fun update(customer: Customer) = customerDao.update(customer.toEntity())
}

@Singleton
class SupplierRepository @Inject constructor(
    private val supplierDao: SupplierDao,
) {
    fun observeAll(): Flow<List<Supplier>> = supplierDao.observeAll().map { list -> list.map { it.toDomain() } }

    fun observeSearch(query: String): Flow<List<Supplier>> =
        supplierDao.observeSearch(query).map { list -> list.map { it.toDomain() } }

    fun observeById(id: Long): Flow<Supplier?> = supplierDao.observeById(id).map { it?.toDomain() }

    suspend fun getById(id: Long): Supplier? = supplierDao.getById(id)?.toDomain()

    suspend fun create(supplier: Supplier): Long = supplierDao.insert(supplier.toEntity())

    suspend fun update(supplier: Supplier) = supplierDao.update(supplier.toEntity())

    suspend fun archive(supplierId: Long, now: Long = System.currentTimeMillis()) =
        supplierDao.archive(supplierId, now)
}

/**
 * Builds the read-only profile screens (spec §7/§8). Phase 2 only wires up
 * what's free from existing data (order count for a customer via OrderDao);
 * money aggregates stay at zero until the Phase 4 financial engine exists —
 * intentionally, per spec's "do not implement full receivables/payables yet".
 */
@Singleton
class PartyProfileRepository @Inject constructor(
    private val customerRepository: CustomerRepository,
    private val supplierRepository: SupplierRepository,
    private val orderDao: OrderDao,
) {
    suspend fun getCustomerProfile(customerId: Long): CustomerProfile? {
        val customer = customerRepository.getById(customerId) ?: return null
        val orderCount = orderDao.observeAll().first().count { it.customerId == customerId }
        return CustomerProfile(customer = customer, totalOrders = orderCount)
    }

    suspend fun getSupplierProfile(supplierId: Long): SupplierProfile? {
        val supplier = supplierRepository.getById(supplierId) ?: return null
        return SupplierProfile(supplier = supplier)
    }
}

private fun CustomerEntity.toDomain() = Customer(
    id = id, name = name, mobile = mobile, address = address, city = city,
    notes = notes, createdAt = createdAt, updatedAt = updatedAt,
)

private fun Customer.toEntity() = CustomerEntity(
    id = id, name = name, mobile = mobile, address = address, city = city,
    notes = notes, createdAt = createdAt, updatedAt = updatedAt,
)

private fun SupplierEntity.toDomain() = Supplier(
    id = id, name = name, phone = phone, address = address, notes = notes,
    isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
)

private fun Supplier.toEntity() = SupplierEntity(
    id = id, name = name, phone = phone, address = address, notes = notes,
    isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
)
