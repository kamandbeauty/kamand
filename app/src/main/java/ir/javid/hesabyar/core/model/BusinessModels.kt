package ir.javid.hesabyar.core.model

import ir.javid.hesabyar.data.local.entity.*

enum class InvoiceKind { SALE, PURCHASE }

data class InvoiceLineInput(
    val productId: Long,
    val quantity: Double,
    val unitPrice: Long,
    val discountAmount: Long = 0,
    val description: String = ""
)

data class InvoiceInput(
    val partyId: Long? = null,
    val dateEpochDay: Long,
    val lines: List<InvoiceLineInput>,
    val discountAmount: Long = 0,
    val taxEnabled: Boolean = false,
    val taxRate: Double = 0.0,
    val paidAmount: Long = 0,
    val cashAccountId: Long? = null,
    val notes: String = ""
)

data class InvoicePdfLine(
    val name: String,
    val quantity: Double,
    val unitPrice: Long,
    val total: Long
)

data class InvoiceDocument(
    val kind: InvoiceKind,
    val invoiceNumber: String,
    val partyName: String?,
    val dateEpochDay: Long,
    val lines: List<InvoicePdfLine>,
    val subtotal: Long,
    val discount: Long,
    val tax: Long,
    val total: Long,
    val paid: Long,
    val balance: Long,
    val notes: String
)

data class JournalLineInput(
    val accountId: Long,
    val debit: Long = 0,
    val credit: Long = 0,
    val description: String = ""
)

data class JournalInput(
    val dateEpochDay: Long,
    val description: String,
    val lines: List<JournalLineInput>
)

data class DashboardSummary(
    val salesToday: Long = 0,
    val purchasesToday: Long = 0,
    val profitToday: Long = 0,
    val cashBalance: Long = 0,
    val bankBalance: Long = 0,
    val invoicesToday: Int = 0,
    val debtors: Long = 0,
    val creditors: Long = 0,
    val lowStockCount: Int = 0
)

data class ProfitLossSummary(
    val sales: Long,
    val costOfGoods: Long,
    val expenses: Long,
    val otherIncome: Long
) {
    val netProfit: Long get() = sales - costOfGoods - expenses + otherIncome
}

data class LicenseStatus(
    val tier: String = "FREE",
    val isProfessional: Boolean = false,
    val reason: String = "نسخه رایگان"
)
