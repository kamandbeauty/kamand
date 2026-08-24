package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.InterestCalculationMethod

@Entity(
    tableName = "settlement_plans",
    foreignKeys = [
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = SalesChannelEntity::class, parentColumns = ["id"], childColumns = ["salesChannelId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("orderId"), Index("salesChannelId")],
)
data class SettlementPlanEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
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

@Entity(
    tableName = "installments",
    foreignKeys = [
        ForeignKey(entity = SettlementPlanEntity::class, parentColumns = ["id"], childColumns = ["settlementPlanId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ReceivableEntity::class, parentColumns = ["id"], childColumns = ["receivableId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("settlementPlanId"), Index("receivableId")],
)
data class InstallmentEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val settlementPlanId: Long,
    val sequenceNumber: Int,
    val principal: Money,
    val interest: Money = Money.ZERO,
    val dueDate: Long,
    val receivableId: Long? = null,
)
