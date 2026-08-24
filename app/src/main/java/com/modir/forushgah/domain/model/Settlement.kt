package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class InterestCalculationMethod { NONE, FLAT_PERCENT_PER_INSTALLMENT }

/**
 * Configuration for how an order's payment is settled: commission, down
 * payment, and installment schedule. The calculation engine that consumes
 * this (see spec section 16-17) lands in Phase 5 — this is the schema only.
 */
data class SettlementPlan(
    val id: Long = 0,
    val orderId: Long,
    val salesChannelId: Long?,
    val grossAmount: Money,
    val commissionPercent: Double = 0.0,
    val downPaymentPercent: Double = 0.0,
    val installmentCount: Int = 0,
    val monthlyInterestPercent: Double = 0.0,
    val interestMethod: InterestCalculationMethod = InterestCalculationMethod.NONE,
    val settlementDelayDays: Int = 0,
)

data class Installment(
    val id: Long = 0,
    val settlementPlanId: Long,
    val sequenceNumber: Int,
    val principal: Money,
    val interest: Money = Money.ZERO,
    val dueDate: Long,
    val receivableId: Long? = null,
)
