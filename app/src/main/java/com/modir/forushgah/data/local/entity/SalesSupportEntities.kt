package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money

@Entity(
    tableName = "payments",
    foreignKeys = [
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = PaymentMethodEntity::class, parentColumns = ["id"], childColumns = ["paymentMethodId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("orderId"), Index("paymentMethodId")],
)
data class PaymentEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long?,
    val amount: Money,
    val method: String, // denormalized display label (survives method rename/delete)
    val paymentMethodId: Long? = null,
    val paidAt: Long,
    val reference: String? = null,
    val notes: String? = null,
)

@Entity(tableName = "payment_methods", indices = [Index("name", unique = true)])
data class PaymentMethodEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val isBuiltIn: Boolean = false,
)

@Entity(tableName = "sales_channels", indices = [Index("name", unique = true)])
data class SalesChannelEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val defaultCommissionPercent: Double = 0.0,
    val isBuiltIn: Boolean = false,
)

@Entity(tableName = "shipping_providers", indices = [Index("name", unique = true)])
data class ShippingProviderEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
)
