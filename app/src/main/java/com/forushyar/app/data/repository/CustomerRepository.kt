package com.forushyar.app.data.repository

import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.entity.Customer
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CustomerRepository @Inject constructor(
    private val dao: CustomerDao
) {
    fun observeAll(): Flow<List<Customer>> = dao.observeAll()

    fun search(query: String): Flow<List<Customer>> = dao.search(query)

    fun observeById(id: Long): Flow<Customer?> = dao.observeById(id)

    fun observeCount(): Flow<Int> = dao.observeCount()

    suspend fun add(customer: Customer): Long = dao.insert(customer)

    suspend fun update(customer: Customer) = dao.update(customer)

    suspend fun delete(customer: Customer) = dao.delete(customer)
}
