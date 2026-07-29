package ir.javid.hesabyar.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/** All monetary values are stored as rial in Long to prevent floating-point rounding errors. */
@Entity(tableName = "app_settings")
data class AppSettingsEntity(
    @PrimaryKey val id: Int = 1,
    val businessName: String = "",
    val ownerName: String = "",
    val phone: String = "",
    val address: String = "",
    val currency: String = "TOMAN",
    val taxEnabled: Boolean = false,
    val taxRate: Double = 10.0,
    val invoicePrefix: String = "ف",
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "product_categories", indices = [Index(value = ["name"], unique = true)])
data class ProductCategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val description: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "products",
    foreignKeys = [ForeignKey(
        entity = ProductCategoryEntity::class,
        parentColumns = ["id"],
        childColumns = ["categoryId"],
        onDelete = ForeignKey.SET_NULL
    )],
    indices = [Index("categoryId"), Index("name"), Index(value = ["sku"], unique = true)]
)
data class ProductEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val sku: String? = null,
    val categoryId: Long? = null,
    val unit: String = "عدد",
    val purchasePrice: Long = 0,
    val salePrice: Long = 0,
    val stock: Double = 0.0,
    val minimumStock: Double = 0.0,
    val notes: String = "",
    /** Services can be invoiced without changing inventory. */
    val trackInventory: Boolean = true,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "inventory_transactions",
    foreignKeys = [ForeignKey(
        entity = ProductEntity::class,
        parentColumns = ["id"],
        childColumns = ["productId"],
        onDelete = ForeignKey.RESTRICT
    )],
    indices = [Index("productId"), Index("dateEpochDay"), Index("referenceId")]
)
data class InventoryTransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val productId: Long,
    /** PURCHASE, SALE, PURCHASE_RETURN, SALE_RETURN, ADJUSTMENT */
    val type: String,
    /** Positive adds stock, negative subtracts it. */
    val quantity: Double,
    val unitCost: Long = 0,
    val referenceId: Long? = null,
    val referenceType: String? = null,
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "parties", indices = [Index("name"), Index("type"), Index("phone")])
data class PartyEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** CUSTOMER, SUPPLIER, OTHER */
    val type: String,
    val phone: String = "",
    val address: String = "",
    val notes: String = "",
    /** Positive means the party owes this business; negative means we owe them. */
    val balance: Long = 0,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "party_transactions",
    foreignKeys = [ForeignKey(
        entity = PartyEntity::class,
        parentColumns = ["id"],
        childColumns = ["partyId"],
        onDelete = ForeignKey.RESTRICT
    )],
    indices = [Index("partyId"), Index("dateEpochDay"), Index("referenceId")]
)
data class PartyTransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val partyId: Long,
    /** SALE, PURCHASE, RECEIPT, PAYMENT, OPENING_BALANCE, ADJUSTMENT */
    val type: String,
    /** Effect on party balance; positive means receivable. */
    val amount: Long,
    val dateEpochDay: Long,
    val referenceId: Long? = null,
    val referenceType: String? = null,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "sales_invoices", indices = [Index(value = ["invoiceNumber"], unique = true), Index("partyId"), Index("dateEpochDay")])
data class SalesInvoiceEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val invoiceNumber: String,
    val partyId: Long? = null,
    val dateEpochDay: Long,
    /** DRAFT, FINAL, RETURNED, CANCELLED */
    val status: String = "FINAL",
    val subtotal: Long = 0,
    val discountAmount: Long = 0,
    val taxAmount: Long = 0,
    val totalAmount: Long = 0,
    val paidAmount: Long = 0,
    val balanceAmount: Long = 0,
    val cashAccountId: Long? = null,
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "sales_invoice_items",
    foreignKeys = [
        ForeignKey(entity = SalesInvoiceEntity::class, parentColumns = ["id"], childColumns = ["invoiceId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ProductEntity::class, parentColumns = ["id"], childColumns = ["productId"], onDelete = ForeignKey.RESTRICT)
    ],
    indices = [Index("invoiceId"), Index("productId")]
)
data class SalesInvoiceItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val invoiceId: Long,
    val productId: Long,
    val description: String = "",
    val quantity: Double,
    val unitPrice: Long,
    val discountAmount: Long = 0,
    val taxAmount: Long = 0,
    val totalAmount: Long,
    /** Cost at the time of sale, retained for historical profit reports. */
    val unitCost: Long = 0,
    val tracksInventory: Boolean = true
)

@Entity(tableName = "purchase_invoices", indices = [Index(value = ["invoiceNumber"], unique = true), Index("partyId"), Index("dateEpochDay")])
data class PurchaseInvoiceEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val invoiceNumber: String,
    val partyId: Long? = null,
    val dateEpochDay: Long,
    val status: String = "FINAL",
    val subtotal: Long = 0,
    val discountAmount: Long = 0,
    val taxAmount: Long = 0,
    val totalAmount: Long = 0,
    val paidAmount: Long = 0,
    val balanceAmount: Long = 0,
    val cashAccountId: Long? = null,
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "purchase_invoice_items",
    foreignKeys = [
        ForeignKey(entity = PurchaseInvoiceEntity::class, parentColumns = ["id"], childColumns = ["invoiceId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = ProductEntity::class, parentColumns = ["id"], childColumns = ["productId"], onDelete = ForeignKey.RESTRICT)
    ],
    indices = [Index("invoiceId"), Index("productId")]
)
data class PurchaseInvoiceItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val invoiceId: Long,
    val productId: Long,
    val description: String = "",
    val quantity: Double,
    val unitPrice: Long,
    val discountAmount: Long = 0,
    val taxAmount: Long = 0,
    val totalAmount: Long,
    val tracksInventory: Boolean = true
)

@Entity(tableName = "cash_accounts", indices = [Index(value = ["name"], unique = true)])
data class CashAccountEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** CASH, BANK */
    val type: String,
    val bankName: String = "",
    val cardNumber: String = "",
    val accountNumber: String = "",
    val openingBalance: Long = 0,
    val balance: Long = 0,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "receipts", indices = [Index("partyId"), Index("cashAccountId"), Index("dateEpochDay")])
data class ReceiptEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val partyId: Long? = null,
    val cashAccountId: Long,
    val amount: Long,
    /** CASH, CARD, TRANSFER, CHEQUE */
    val method: String = "CASH",
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "payments", indices = [Index("partyId"), Index("cashAccountId"), Index("dateEpochDay")])
data class PaymentEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val partyId: Long? = null,
    val cashAccountId: Long,
    val amount: Long,
    val method: String = "CASH",
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "expenses", indices = [Index("cashAccountId"), Index("dateEpochDay")])
data class ExpenseEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val amount: Long,
    val cashAccountId: Long,
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "incomes", indices = [Index("cashAccountId"), Index("dateEpochDay")])
data class IncomeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val amount: Long,
    val cashAccountId: Long,
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "cash_transfers", indices = [Index("fromAccountId"), Index("toAccountId"), Index("dateEpochDay")])
data class CashTransferEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val fromAccountId: Long,
    val toAccountId: Long,
    val amount: Long,
    val dateEpochDay: Long,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "accounts", indices = [Index(value = ["code"], unique = true), Index("parentId"), Index("type")])
data class AccountEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val code: String,
    val name: String,
    /** ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE */
    val type: String,
    val parentId: Long? = null,
    val level: Int = 1,
    val isSystem: Boolean = false,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "journal_entries", indices = [Index(value = ["entryNumber"], unique = true), Index("dateEpochDay"), Index("referenceId")])
data class JournalEntryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val entryNumber: String,
    val dateEpochDay: Long,
    val description: String,
    /** MANUAL, SALE, PURCHASE, RECEIPT, PAYMENT, EXPENSE, INCOME, TRANSFER */
    val sourceType: String = "MANUAL",
    val referenceId: Long? = null,
    val isPosted: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "journal_items",
    foreignKeys = [
        ForeignKey(entity = JournalEntryEntity::class, parentColumns = ["id"], childColumns = ["journalEntryId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = AccountEntity::class, parentColumns = ["id"], childColumns = ["accountId"], onDelete = ForeignKey.RESTRICT)
    ],
    indices = [Index("journalEntryId"), Index("accountId")]
)
data class JournalItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val journalEntryId: Long,
    val accountId: Long,
    val debit: Long = 0,
    val credit: Long = 0,
    val description: String = ""
)

@Entity(tableName = "licenses")
data class LicenseEntity(
    @PrimaryKey val id: Int = 1,
    val tier: String = "FREE",
    val activatedAt: Long? = null,
    val expiresAt: Long? = null,
    val token: String = ""
)
