package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

data class Customer(
    val id: Long = 0,
    val name: String,
    val mobile: String? = null,
    val address: String? = null,
    val city: String? = null,
    val notes: String? = null,
    val createdAt: Long,
    val updatedAt: Long,
)

/** Aggregated, computed customer statistics — never stored directly, always derived.
 * Phase 2 wires this to real order data ONLY where it's free (order count from
 * OrderDao); totalProfit/outstandingReceivable stay at zero placeholders until
 * the Phase 4 financial engine lands (per spec §8: "Do not implement full
 * receivables yet"). */
data class CustomerProfile(
    val customer: Customer,
    val totalOrders: Int = 0,
    val totalPurchases: Money = Money.ZERO,
    val totalProfit: Money = Money.ZERO,
    val outstandingReceivable: Money = Money.ZERO,
)

data class Supplier(
    val id: Long = 0,
    val name: String,
    val phone: String? = null,
    val address: String? = null,
    val notes: String? = null,
    val isActive: Boolean = true,
    val createdAt: Long,
    val updatedAt: Long,
)

/** Phase 2 foundation only: totalPurchased/totalPaid/outstandingDebt are wired
 * to zero until the Phase 4/5 payable engine is built (per spec §7: "Do not
 * implement the complete payable engine yet"). */
data class SupplierProfile(
    val supplier: Supplier,
    val totalPurchased: Money = Money.ZERO,
    val totalPaid: Money = Money.ZERO,
    val outstandingDebt: Money = Money.ZERO,
)
