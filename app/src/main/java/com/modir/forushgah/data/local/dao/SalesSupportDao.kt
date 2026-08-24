package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.PaymentEntity
import com.modir.forushgah.data.local.entity.SalesChannelEntity
import com.modir.forushgah.data.local.entity.ShippingProviderEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface PaymentDao {
    @Insert
    suspend fun insert(payment: PaymentEntity): Long

    @Query("SELECT * FROM payments WHERE orderId = :orderId ORDER BY paidAt DESC")
    suspend fun getForOrder(orderId: Long): List<PaymentEntity>
}

@Dao
interface SalesChannelDao {
    @Insert
    suspend fun insert(channel: SalesChannelEntity): Long

    @Query("SELECT * FROM sales_channels ORDER BY name ASC")
    fun observeAll(): Flow<List<SalesChannelEntity>>
}

@Dao
interface ShippingProviderDao {
    @Insert
    suspend fun insert(provider: ShippingProviderEntity): Long

    @Query("SELECT * FROM shipping_providers ORDER BY name ASC")
    fun observeAll(): Flow<List<ShippingProviderEntity>>
}
