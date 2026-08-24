package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.InstallmentEntity
import com.modir.forushgah.data.local.entity.SettlementPlanEntity
import com.modir.forushgah.data.local.entity.StoreProfileEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SettlementPlanDao {
    @Insert
    suspend fun insert(plan: SettlementPlanEntity): Long

    @Insert
    suspend fun insertInstallments(installments: List<InstallmentEntity>)

    @Query("SELECT * FROM settlement_plans WHERE orderId = :orderId")
    suspend fun getForOrder(orderId: Long): SettlementPlanEntity?

    @Query("SELECT * FROM installments WHERE settlementPlanId = :planId ORDER BY sequenceNumber ASC")
    suspend fun getInstallments(planId: Long): List<InstallmentEntity>
}

@Dao
interface StoreProfileDao {
    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE)
    suspend fun upsert(profile: StoreProfileEntity)

    @Query("SELECT * FROM store_profile WHERE id = 1")
    fun observe(): Flow<StoreProfileEntity?>

    @Query("SELECT * FROM store_profile WHERE id = 1")
    suspend fun get(): StoreProfileEntity?
}
