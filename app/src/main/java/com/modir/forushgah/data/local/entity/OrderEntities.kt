package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ShippingPaymentType

@Entity(
    tableName = "orders",
    foreignKeys = [
        ForeignKey(entity = CustomerEntity::class, parentColumns = ["id"], childColumns = ["customerId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = SalesChannelEntity::class, parentColumns = ["id"], childColumns = ["salesChannelId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = ShippingProviderEntity::class, parentColumns = ["id"], childColumns = ["shippingProviderId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("customerId"), Index("orderNumber", unique = true), Index("status"), Index("orderDate")],
)
data class OrderEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderNumber: String,
    val customerId: Long?,
    val orderDate: Long,
    val discount: Money = Money.ZERO,
    val shippingChargedToCustomer: Money = Money.ZERO,
    val paymentMethodId: Long? = null,
    val salesChannelId: Long? = null,
    val status: OrderStatus = OrderStatus.NEW,
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
    val actualShippingCost: Money = Money.ZERO,
    val packagingCost: Money = Money.ZERO,
    val commission: Money = Money.ZERO,
    val notes: String? = null,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
)

@Entity(
    tableName = "order_items",
    foreignKeys = [
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ProductEntity::class, parentColumns = ["id"], childColumns = ["productId"], onDelete = ForeignKey.RESTRICT),
    ],
    indices = [Index("orderId"), Index("productId")],
)
data class OrderItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long,
    val productId: Long,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money,
    val discount: Money = Money.ZERO,
)
