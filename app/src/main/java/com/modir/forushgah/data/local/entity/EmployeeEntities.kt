package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.CommissionBasis

@Entity(tableName = "employees")
data class EmployeeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val role: String? = null,
    val isActive: Boolean = true,
)

@Entity(
    tableName = "employee_commission_rules",
    foreignKeys = [ForeignKey(entity = EmployeeEntity::class, parentColumns = ["id"], childColumns = ["employeeId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("employeeId")],
)
data class EmployeeCommissionRuleEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val employeeId: Long,
    val basis: CommissionBasis,
    val fixedAmount: Money = Money.ZERO,
    val percent: Double = 0.0,
)
