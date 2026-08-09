package ir.factoryar.core.domain.model

/** ترتیب مرتب‌سازی فهرست بدهکاران */
enum class DebtorSort(val faName: String) {
    AMOUNT("بیشترین مبلغ"),
    OVERDUE_DAYS("بیشترین تأخیر"),
    NAME("نام مشتری"),
}

/**
 * یک مشتری بدهکار همراه با جزئیات معوقات.
 * محاسبه‌ها در لایه Domain انجام می‌شود تا قابل تست باشد.
 */
data class DebtorEntry(
    val customer: Customer,
    /** کل مانده بدهی (شامل فاکتورهای سررسید نشده) */
    val totalDebt: Long,
    /** فقط مانده فاکتورهای معوق (سررسید گذشته) */
    val overdueAmount: Long,
    val overdueInvoiceCount: Int,
    /** بیشترین روز تأخیر بین فاکتورهای معوق */
    val maxOverdueDays: Int,
    /** آخرین خرید */
    val lastPurchaseAt: Long? = null,
    /** فاکتورهای معوق برای ساخت متن یادآوری */
    val overdueInvoices: List<Invoice> = emptyList(),
) {
    val hasOverdue: Boolean get() = overdueInvoiceCount > 0
}

/** خلاصه کل مطالبات برای هدر صفحه و نوتیفیکیشن */
data class DebtorsSummary(
    val debtors: List<DebtorEntry> = emptyList(),
    val totalDebt: Long = 0,
    val totalOverdue: Long = 0,
    val overdueCustomerCount: Int = 0,
)

/** ابزار ساخت متن آماده یادآوری برای ارسال از طریق پیامک/واتساپ/تلگرام */
object ReminderMessageBuilder {

    /**
     * متن مؤدبانه یادآوری بدهی.
     * @param formatMoney تابع قالب‌بندی مبلغ (تزریق‌شده تا Domain به لایه common وابسته نشود)
     * @param formatDate تابع قالب‌بندی تاریخ شمسی
     */
    fun build(
        entry: DebtorEntry,
        businessName: String,
        businessPhone: String = "",
        formatMoney: (Long) -> String,
        formatDate: (Long) -> String,
    ): String = buildString {
        append(entry.customer.name.trim().ifBlank { "مشتری گرامی" })
        append(" عزیز، با سلام؛\n")
        if (entry.overdueInvoices.isEmpty()) {
            append("مانده حساب شما نزد ")
            append(businessName.ifBlank { "ما" })
            append(" مبلغ ")
            append(formatMoney(entry.totalDebt))
            append(" می‌باشد.\n")
        } else {
            append("مانده حساب شما نزد ")
            append(businessName.ifBlank { "ما" })
            append(" به شرح زیر است:\n")
            entry.overdueInvoices.take(MAX_LISTED_INVOICES).forEach { inv ->
                append("• فاکتور ")
                append(inv.number)
                if (inv.dueDate != null) {
                    append(" (سررسید ")
                    append(formatDate(inv.dueDate))
                    append(")")
                }
                append(": ")
                append(formatMoney(inv.remainingAmount))
                append("\n")
            }
            if (entry.overdueInvoices.size > MAX_LISTED_INVOICES) {
                append("• و ")
                append((entry.overdueInvoices.size - MAX_LISTED_INVOICES).toString())
                append(" فاکتور دیگر\n")
            }
            append("جمع کل بدهی: ")
            append(formatMoney(entry.totalDebt))
            append("\n")
        }
        append("خواهشمند است در اولین فرصت نسبت به تسویه اقدام فرمایید. ")
        append("در صورت واریز، این پیام را نادیده بگیرید.\n")
        if (businessPhone.isNotBlank()) {
            append("تماس: ")
            append(businessPhone)
            append("\n")
        }
        append("با تشکر — ")
        append(businessName.ifBlank { "واحد مالی" })
    }

    private const val MAX_LISTED_INVOICES = 5
}
