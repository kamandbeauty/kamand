package ir.factoryar.core.database.entity

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(
    tableName = "invoices",
    foreignKeys = [
        ForeignKey(
            entity = CustomerEntity::class,
            parentColumns = ["id"],
            childColumns = ["customerId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index(value = ["number"], unique = true),
        Index(value = ["customerId"]),
        Index(value = ["type"]),
        Index(value = ["issueDate"]),
        Index(value = ["status"]),
    ],
)
data class InvoiceEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val number: String,
    /** PROFORMA / SALE / PURCHASE */
    val type: String,
    val customerId: Long?,
    val issueDate: Long,
    val dueDate: Long?,
    /** UNPAID / PARTIAL / PAID */
    val status: String,
    val paidAmount: Long,
    val globalDiscount: Long,
    val note: String,
    val terms: String,
    val signaturePath: String?,
    // مقادیر cache شده برای گزارش‌گیری سریع
    val subtotal: Long,
    val discountTotal: Long,
    val taxTotal: Long,
    val grandTotal: Long,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "invoice_items",
    foreignKeys = [
        ForeignKey(
            entity = InvoiceEntity::class,
            parentColumns = ["id"],
            childColumns = ["invoiceId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["invoiceId"]), Index(value = ["productId"])],
)
data class InvoiceItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val invoiceId: Long,
    val title: String,
    val quantity: Double,
    val unitPrice: Long,
    val discountPercent: Double,
    val taxPercent: Double,
    val sortOrder: Int,
    /** اتصال به کالای انبار — برای کسر/افزایش خودکار موجودی */
    val productId: Long? = null,
    /** snapshot بهای تمام‌شده واحد در لحظه صدور فاکتور */
    val costPrice: Long = 0,
)

data class InvoiceWithItemsEntity(
    @Embedded val invoice: InvoiceEntity,
    @Relation(parentColumn = "id", entityColumn = "invoiceId")
    val items: List<InvoiceItemEntity>,
)

@Entity(
    tableName = "recurring_invoices",
    indices = [Index(value = ["nextRunDate"]), Index(value = ["active"])],
)
data class RecurringInvoiceEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val customerId: Long?,
    /** WEEKLY / MONTHLY / YEARLY */
    val interval: String,
    val startDate: Long,
    val nextRunDate: Long,
    val active: Boolean,
    /** JSON از RecurringTemplate */
    val templateJson: String,
)

@Entity(tableName = "business_profiles")
data class BusinessProfileEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val phone: String,
    val address: String,
    val email: String,
    val logoPath: String?,
    val defaultTaxPercent: Double,
    val defaultTerms: String,
    val isActive: Boolean,
)
