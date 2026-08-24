package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

enum class ExpenseGroup {
    SALES, SHIPPING, PACKAGING, GENERAL
}

data class ExpenseCategory(
    val id: Long = 0,
    val name: String,
    val group: ExpenseGroup,
    val isBuiltIn: Boolean = false,
)

data class Expense(
    val id: Long = 0,
    val categoryId: Long,
    val amount: Money,
    val date: Long,
    val description: String? = null,
    val orderId: Long? = null,
    val employeeId: Long? = null,
)
