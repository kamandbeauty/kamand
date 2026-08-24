package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.SupplierEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CustomerDao {
    @Insert
    suspend fun insert(customer: CustomerEntity): Long

    @Update
    suspend fun update(customer: CustomerEntity)

    @Query("SELECT * FROM customers ORDER BY name ASC")
    fun observeAll(): Flow<List<CustomerEntity>>

    @Query("SELECT * FROM customers WHERE id = :id")
    suspend fun getById(id: Long): CustomerEntity?

    @Query("SELECT * FROM customers WHERE id = :id")
    fun observeById(id: Long): Flow<CustomerEntity?>

    @Query("SELECT * FROM customers WHERE name LIKE '%' || :query || '%' OR mobile LIKE '%' || :query || '%' ORDER BY name ASC LIMIT 30")
    fun observeSearch(query: String): Flow<List<CustomerEntity>>

    @Query("SELECT COUNT(*) FROM customers")
    fun observeCount(): Flow<Int>
}

@Dao
interface SupplierDao {
    @Insert
    suspend fun insert(supplier: SupplierEntity): Long

    @Update
    suspend fun update(supplier: SupplierEntity)

    @Query("UPDATE suppliers SET isActive = 0, updatedAt = :now WHERE id = :supplierId")
    suspend fun archive(supplierId: Long, now: Long)

    @Query("SELECT * FROM suppliers WHERE isActive = 1 ORDER BY name ASC")
    fun observeAll(): Flow<List<SupplierEntity>>

    @Query("SELECT * FROM suppliers WHERE id = :id")
    suspend fun getById(id: Long): SupplierEntity?

    @Query("SELECT * FROM suppliers WHERE id = :id")
    fun observeById(id: Long): Flow<SupplierEntity?>

    @Query("SELECT * FROM suppliers WHERE isActive = 1 AND name LIKE '%' || :query || '%' ORDER BY name ASC LIMIT 30")
    fun observeSearch(query: String): Flow<List<SupplierEntity>>
}
