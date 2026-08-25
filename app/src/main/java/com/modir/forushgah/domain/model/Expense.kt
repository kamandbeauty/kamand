package com.modir.forushgah.domain.model

import com.modir.forushgah.core.common.Money

/**
 * Phase 4.2: standalone expense categories — the FINAL set. The Phase 1
 * conceptual groups (SALES / GENERAL) were removed: a store does not spend
 * money "on sales", and "general" was too vague to report on.
 *
 * Enum values stay English (stored as `.name` via EnumConverters); the
 * Persian display labels live in [persianName] and are also the names of the
 * built-in seeded categories.
 */
enum class ExpenseGroup {
    PACKAGING, // بسته‌بندی (bulk purchase of bags/boxes, etc.)
    SHIPPING, // ارسال
    PURCHASE, // خرید (other purchases)
    RENT, // اجاره
    SALARY, // حقوق
    UTILITIES, // قبوض و خدمات
    OTHER, // سایر

    /** Persian display label — single source of truth for UI and seeding. */
    val persianName: String
        get() = when (this) {
            PACKAGING -> "بسته‌بندی"
            SHIPPING -> "ارسال"
            PURCHASE -> "خرید"
            RENT -> "اجاره"
            SALARY -> "حقوق"
            UTILITIES -> "قبوض و خدمات"
            OTHER -> "سایر"
        }
}

data class ExpenseCategory(
    val id: Long = 0,
    val name: String,
    val group: ExpenseGroup,
    val isBuiltIn: Boolean = false,
)

/**
 * A standalone expense (Phase 4.2). [amount] is ALWAYS positive — the
 * negative sign belongs to the financial event it creates
 * (TransactionType.EXPENSE), matching the rest of the financial engine.
 *
 * [deletedAt] implements the soft delete: a deleted expense disappears from
 * the active lists but the row (and its full financial history) is preserved,
 * exactly like the soft-deleted orders of Phase 4.1.
 */
data class Expense(
    val id: Long = 0,
    val categoryId: Long,
    val amount: Money,
    val date: Long,
    val description: String? = null,
    val orderId: Long? = null,
    val employeeId: Long? = null,
    val deletedAt: Long? = null,
) {
    val isDeleted: Boolean get() = deletedAt != null
}
