package com.forushyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.forushyar.app.data.local.entity.Customer
import kotlinx.coroutines.flow.Flow

@Dao
interface CustomerDao {

    @Query("SELECT * FROM customers ORDER BY createdDate DESC")
    fun observeAll(): Flow<List<Customer>>

    @Query(
        "SELECT * FROM customers " +
            "WHERE name LIKE '%' || :query || '%' " +
            "OR phone LIKE '%' || :query || '%' " +
            "OR instagramId LIKE '%' || :query || '%' " +
            "ORDER BY name"
    )
    fun search(query: String): Flow<List<Customer>>

    @Query("SELECT * FROM customers WHERE id = :id")
    fun observeById(id: Long): Flow<Customer?>

    @Query("SELECT COUNT(*) FROM customers")
    fun observeCount(): Flow<Int>

    @Query("SELECT * FROM customers ORDER BY id")
    suspend fun getAll(): List<Customer>

    @Query("DELETE FROM customers")
    suspend fun clearAll()

    @Insert
    suspend fun insert(customer: Customer): Long

    @Update
    suspend fun update(customer: Customer)

    @Delete
    suspend fun delete(customer: Customer)

    @Query("DELETE FROM customers WHERE id = :id")
    suspend fun deleteById(id: Long)
}
