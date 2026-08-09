package ir.factoryar.core.domain.model

data class Customer(
    val id: Long = 0,
    val name: String,
    val phone: String = "",
    val email: String = "",
    val address: String = "",
    val note: String = "",
    val createdAt: Long = 0,
)

/** مشتری + خلاصه مالی (برای لیست مشتریان) */
data class CustomerWithBalance(
    val customer: Customer,
    val totalDebt: Long = 0,
    val invoiceCount: Int = 0,
    val lastPurchaseAt: Long? = null,
    val hasOverdue: Boolean = false,
)

/** دفتر حساب مشتری: فاکتورها + جمع‌ها */
data class CustomerLedger(
    val customer: Customer,
    val invoices: List<Invoice>,
    val totalSales: Long,
    val totalPaid: Long,
    val totalDebt: Long,
)
