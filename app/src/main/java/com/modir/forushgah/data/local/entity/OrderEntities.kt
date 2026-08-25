package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ShippingPaymentType

@Entity(
    tableName = "orders",
    foreignKeys = [
        ForeignKey(entity = CustomerEntity::class, parentColumns = ["id"], childColumns = ["customerId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = SalesChannelEntity::class, parentColumns = ["id"], childColumns = ["salesChannelId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = ShippingProviderEntity::class, parentColumns = ["id"], childColumns = ["shippingProviderId"], onDelete = ForeignKey.SET_NULL),
    ],
    // orderNumber is NOT unique: Phase 4.1 soft-deletes keep the old row when
    // an invoice is edited (old DELETED row + replacement share the number).
    indices = [Index("customerId"), Index("supplierId"), Index("orderNumber"), Index("status"), Index("orderDate")],
)
data class OrderEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderNumber: String,
    val customerId: Long?,
    /** Phase 3.1: supplier link for purchase invoices. */
    val supplierId: Long? = null,
    /** Phase 3.1: invoice kind (SALES / PURCHASE), stored via OrderKind converter. */
    val kind: OrderKind = OrderKind.SALES,
    /** Phase 4.1 (Rubi paymentType): false = credit sale; the order total
     * becomes customer receivable until paid. */
    val isCashPayment: Boolean = true,
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
    /** Phase 3.1 shipment tracking: String — tracking codes may have leading
     * zeros, letters, prefixes, hyphens. Never numeric (spec §21). */
    val trackingCode: String? = null,
    /** Shipping date (epoch millis of the shipped day). */
    val shippedAt: Long? = null,
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
    /** Null for free/manual invoice lines (Rubi free items). */
    val productId: Long? = null,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money,
    val discount: Money = Money.ZERO,
    /** Display name snapshot (Rubi items are title-based). */
    val title: String = "",
    val unit: String = "عدد",
)
