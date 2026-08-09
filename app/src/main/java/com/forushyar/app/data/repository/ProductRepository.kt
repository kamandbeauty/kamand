package com.forushyar.app.data.repository

import com.forushyar.app.data.local.dao.ProductDao
import com.forushyar.app.data.local.entity.Product
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProductRepository @Inject constructor(
    private val dao: ProductDao
) {
    fun observeAll(): Flow<List<Product>> = dao.observeAll()

    fun search(query: String): Flow<List<Product>> = dao.search(query)

    fun observeById(id: Long): Flow<Product?> = dao.observeById(id)

    fun observeCount(): Flow<Int> = dao.observeCount()

    suspend fun add(product: Product): Long = dao.insert(product)

    suspend fun update(product: Product) = dao.update(product)

    suspend fun delete(product: Product) = dao.delete(product)
}
