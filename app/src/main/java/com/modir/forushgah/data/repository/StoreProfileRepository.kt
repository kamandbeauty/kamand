package com.modir.forushgah.data.repository

import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.dao.StoreProfileDao
import com.modir.forushgah.data.local.entity.StoreProfileEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StoreProfileRepository @Inject constructor(
    private val storeProfileDao: StoreProfileDao,
) {
    fun isOnboardingCompleted(): Flow<Boolean> =
        storeProfileDao.observe().map { it?.onboardingCompleted == true }

    suspend fun completeOnboarding(
        storeName: String,
        ownerName: String,
        businessCategory: String,
        startingCashBalance: Money,
    ) {
        storeProfileDao.upsert(
            StoreProfileEntity(
                storeName = storeName,
                ownerName = ownerName,
                businessCategory = businessCategory,
                startingCashBalance = startingCashBalance,
                onboardingCompleted = true,
                createdAt = System.currentTimeMillis(),
            ),
        )
    }
}
