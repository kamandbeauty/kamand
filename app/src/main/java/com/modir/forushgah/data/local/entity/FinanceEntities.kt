package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.domain.model.PayableStatus
import com.modir.forushgah.domain.model.ReceivableStatus
import com.modir.forushgah.domain.model.ReturnReason
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
    indices = [Index("orderId")],
)
data class OrderReturnEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val orderId: Long,
    val reason: ReturnReason,
    val returnShippingCost: Money = Money.ZERO,
    val packagingCostLost: Money = Money.ZERO,
    val revenueReversed: Money = Money.ZERO,
    val restockedToInventory: Boolean = true,
    val date: Long,
)

@Entity(
    tableName = "financial_transactions",
    foreignKeys = [ForeignKey(entity = OrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.SET_NULL)],
    indices = [Index("orderId"), Index("type"), Index("date")],
)
data class FinancialTransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: TransactionType,
    val amount: Money,
    val date: Long,
    val orderId: Long? = null,
    val description: String? = null,
)
