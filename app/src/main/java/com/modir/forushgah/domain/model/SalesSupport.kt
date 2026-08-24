package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

data class Payment(
    val id: Long = 0,
    val orderId: Long?,
    val amount: Money,
    val method: String, // e.g. "نقدی", "کارت‌به‌کارت"
    val paidAt: Long,
    val notes: String? = null,
)

/**
 * "Sales & Settlement Method" engine (spec section 15). Not hardcoded to
 * specific platforms — the user can define custom channels, each optionally
 * carrying a default commission used by the settlement engine (Phase 5).
 */
data class SalesChannel(
    val id: Long = 0,
    val name: String, // نقدی، کارت‌به‌کارت، درگاه، اسنپ‌پی، ترب، باسلام، ...
    val defaultCommissionPercent: Double = 0.0,
    val isBuiltIn: Boolean = false,
)

data class ShippingProvider(
    val id: Long = 0,
    val name: String, // پست، تیپاکس، پیک، ...
)
