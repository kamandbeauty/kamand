package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.PaymentEntity
import com.modir.forushgah.data.local.entity.PaymentMethodEntity
import com.modir.forushgah.data.local.entity.RefundEntity
import com.modir.forushgah.data.local.entity.SalesChannelEntity
import com.modir.forushgah.data.local.entity.ShippingProviderEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface PaymentDao {
    @Insert
    suspend fun insert(payment: PaymentEntity): Long

    @Query("SELECT * FROM payments WHERE orderId = :orderId ORDER BY paidAt DESC")
    suspend fun getForOrder(orderId: Long): List<PaymentEntity>

    @Query("SELECT * FROM payments WHERE orderId = :orderId ORDER BY paidAt DESC")
    fun observeForOrder(orderId: Long): Flow<List<PaymentEntity>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE orderId = :orderId")
    suspend fun sumPaidForOrder(orderId: Long): Long
}

@Dao
interface PaymentMethodDao {
    @Insert
    suspend fun insert(method: PaymentMethodEntity): Long

    @Query("SELECT * FROM payment_methods ORDER BY name ASC")
    fun observeAll(): Flow<List<PaymentMethodEntity>>

    @Query("SELECT COUNT(*) FROM payment_methods WHERE name = :name")
    suspend fun countByName(name: String): Int
}

@Dao
interface SalesChannelDao {
    @Insert
    suspend fun insert(channel: SalesChannelEntity): Long

    @Query("SELECT * FROM sales_channels ORDER BY name ASC")
    fun observeAll(): Flow<List<SalesChannelEntity>>

    @Query("SELECT COUNT(*) FROM sales_channels WHERE name = :name")
    suspend fun countByName(name: String): Int
}

@Dao
interface ShippingProviderDao {
    @Insert
    suspend fun insert(provider: ShippingProviderEntity): Long

    @Query("SELECT * FROM shipping_providers ORDER BY name ASC")
    fun observeAll(): Flow<List<ShippingProviderEntity>>

    @Query("SELECT COUNT(*) FROM shipping_providers WHERE name = :name")
    suspend fun countByName(name: String): Int
}

@Dao
interface RefundDao {
    @Insert
    suspend fun insert(refund: RefundEntity): Long

    @Query("SELECT * FROM refunds WHERE orderId = :orderId ORDER BY date DESC")
    fun observeForOrder(orderId: Long): Flow<List<RefundEntity>>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM refunds WHERE orderId = :orderId")
    suspend fun sumRefundedForOrder(orderId: Long): Long
}
