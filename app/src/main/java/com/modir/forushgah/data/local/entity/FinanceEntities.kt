package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.PayableStatus
import com.modir.forushgah.domain.model.ReceivableStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.TransactionType

@Entity(
    tableName = "receivables",
    foreignKeys = [
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = CustomerEntity::class, parentColumns = ["id"], childColumns = ["customerId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("orderId"), Index("customerId"), Index("status"), Index("expectedDate")],
)
data class ReceivableEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long?,
    val customerId: Long?,
    val expectedAmount: Money,
    val expectedDate: Long,
    val receivedAmount: Money = Money.ZERO,
    val status: ReceivableStatus = ReceivableStatus.EXPECTED,
    val notes: String? = null,
)

@Entity(
    tableName = "payables",
    foreignKeys = [ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("supplierId"), Index("status"), Index("dueDate")],
)
data class PayableEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val supplierId: Long,
    val expectedAmount: Money,
    val dueDate: Long?,
    val paidAmount: Money = Money.ZERO,
    val status: PayableStatus = PayableStatus.EXPECTED,
    val notes: String? = null,
)

@Entity(
    tableName = "supplier_payments",
    foreignKeys = [
        ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = PayableEntity::class, parentColumns = ["id"], childColumns = ["payableId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("supplierId"), Index("payableId")],
)
data class SupplierPaymentEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val supplierId: Long,
    val payableId: Long?,
    val amount: Money,
    val paidAt: Long,
    val notes: String? = null,
)

@Entity(
    tableName = "order_returns",
    foreignKeys = [ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("orderId"), Index("status")],
)
data class OrderReturnEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long,
    val reason: ReturnReason,
    val status: ReturnStatus = ReturnStatus.RECEIVED,
    val returnShippingCost: Money = Money.ZERO,
    val packagingCostLost: Money = Money.ZERO,
    val revenueReversed: Money = Money.ZERO,
    val restockedToInventory: Boolean = true,
    val date: Long,
    val createdAt: Long = 0,
)

@Entity(
    tableName = "order_return_items",
    foreignKeys = [
        ForeignKey(entity = OrderReturnEntity::class, parentColumns = ["id"], childColumns = ["returnId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ProductEntity::class, parentColumns = ["id"], childColumns = ["productId"], onDelete = ForeignKey.RESTRICT),
    ],
    indices = [Index("returnId"), Index("productId")],
)
data class OrderReturnItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val returnId: Long,
    val productId: Long,
    val quantity: Int,
)

/** A refund record (spec §24) — original payments are never deleted. */
@Entity(
    tableName = "refunds",
    foreignKeys = [ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("orderId")],
)
data class RefundEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long,
    val amount: Money,
    val date: Long,
    val method: String,
    val reason: String?,
    val note: String? = null,
)

@Entity(
    tableName = "financial_transactions",
    foreignKeys = [
        ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = CustomerEntity::class, parentColumns = ["id"], childColumns = ["customerId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = PaymentEntity::class, parentColumns = ["id"], childColumns = ["paymentId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = RefundEntity::class, parentColumns = ["id"], childColumns = ["refundId"], onDelete = ForeignKey.SET_NULL),
        ForeignKey(entity = OrderReturnEntity::class, parentColumns = ["id"], childColumns = ["returnId"], onDelete = ForeignKey.SET_NULL),
        // Self-reference: reversal corrections point at the event they reverse.
        ForeignKey(entity = FinancialTransactionEntity::class, parentColumns = ["id"], childColumns = ["reversalOfId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [
        Index("orderId"), Index("type"), Index("date"),
        Index("customerId"), Index("supplierId"),
        Index("paymentId"), Index("refundId"), Index("returnId"), Index("reversalOfId"),
    ],
)
data class FinancialTransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: TransactionType,
    val amount: Money,
    val date: Long,
    val orderId: Long? = null,
    val customerId: Long? = null,
    val supplierId: Long? = null,
    val paymentId: Long? = null,
    val refundId: Long? = null,
    val returnId: Long? = null,
    /** Generic reference escape hatch (e.g. "EXPENSE"/<id>) — no FK on purpose. */
    val referenceType: String? = null,
    val referenceId: Long? = null,
    /** Phase 4.1: set when this event reverses another event (cancellation /
     * deletion / edit correction). Amount = -reversed amount. */
    val reversalOfId: Long? = null,
    val description: String? = null,
)
