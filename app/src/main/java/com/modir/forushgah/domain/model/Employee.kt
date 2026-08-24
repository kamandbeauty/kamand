package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class CommissionBasis {
    FIXED_SALARY,
    PERCENT_OF_SALES,
    FIXED_PER_ORDER,
    PERCENT_OF_PROFIT,
}

data class Employee(
    val id: Long = 0,
    val name: String,
    val role: String? = null,
    val isActive: Boolean = true,
)

data class EmployeeCommissionRule(
    val id: Long = 0,
    val employeeId: Long,
    val basis: CommissionBasis,
    val fixedAmount: Money = Money.ZERO,     // used for FIXED_SALARY / FIXED_PER_ORDER
    val percent: Double = 0.0,               // used for PERCENT_OF_SALES / PERCENT_OF_PROFIT
)
