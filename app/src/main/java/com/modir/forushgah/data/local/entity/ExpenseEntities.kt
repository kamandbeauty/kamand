package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.ExpenseGroup

@Entity(tableName = "expense_categories")
data class ExpenseCategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val group: ExpenseGroup,
    val isBuiltIn: Boolean = false,
)

@Entity(
    tableName = "expenses",
    foreignKeys = [
        ForeignKey(entity = ExpenseCategoryEntity::class, parentColumns = ["id"], childColumns = ["categoryId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = EmployeeEntity::class, parentColumns = ["id"], childColumns = ["employeeId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [
        Index("categoryId"), Index("orderId"), Index("employeeId"), Index("date"),
        // Phase 4.2: soft delete — active-list queries filter on deletedAt.
        Index("deletedAt"),
    ],
)
data class ExpenseEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val categoryId: Long,
    val amount: Money,
    val date: Long,
    val description: String? = null,
    val orderId: Long? = null,
    val employeeId: Long? = null,
    /** Phase 4.2: soft delete. Null = active. The row is never physically
     * removed so the financial history stays traceable (like orders). */
    val deletedAt: Long? = null,
)
