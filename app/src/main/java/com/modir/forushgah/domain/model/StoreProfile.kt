package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

/** The store's public identity, printed on Rubi-style invoice headers
 * (Phase 3.1). Phone/address/taxId/bankCard start empty and are filled by a
 * future store-settings screen; the invoice renders whatever is present. */
data class StoreProfile(
    val storeName: String,
    val ownerName: String,
    val businessCategory: String,
    val startingCashBalance: Money,
    val phone: String = "",
    val address: String = "",
    val taxId: String = "",
    val bankCardNumber: String = "",
)
