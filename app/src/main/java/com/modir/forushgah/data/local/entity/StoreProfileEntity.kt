package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money

/** Singleton-ish table (single row, id always 1) holding onboarding output. */
@Entity(tableName = "store_profile")
data class StoreProfileEntity(
    @PrimaryKey val id: Int = 1,
    val storeName: String,
    val ownerName: String,
    val businessCategory: String,
    val startingCashBalance: Money = Money.ZERO,
    val onboardingCompleted: Boolean = false,
    val createdAt: Long,
    /** Phase 3.1 (Rubi business profile): printed in the invoice header/footer.
     * Empty until a store-settings screen provides them (later phase). */
    val phone: String = "",
    val address: String = "",
    val taxId: String = "",
    val bankCardNumber: String = "",
)
