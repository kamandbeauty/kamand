package ir.factoryar.core.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class InvoiceItem(
    val id: Long = 0,
    val invoiceId: Long = 0,
    val title: String,
    val quantity: Double = 1.0,
    /** قیمت واحد (به کوچک‌ترین واحد پول تنظیم‌شده، مثلاً تومان صحیح) */
    val unitPrice: Long,
    /** درصد تخفیف روی همین آیتم (۰ تا ۱۰۰) */
    val discountPercent: Double = 0.0,
    /** درصد مالیات بر ارزش افزوده روی همین آیتم */
    val taxPercent: Double = 0.0,
    val sortOrder: Int = 0,
    /** اتصال به کالای انبار (در صورت انتخاب از انبار) — مبنای کسر/افزایش موجودی */
    val productId: Long? = null,
    /** بهای تمام‌شده واحد در لحظه صدور فاکتور (snapshot برای محاسبه سود) */
    val costPrice: Long = 0,
) {
    /** بهای تمام‌شده کل این سطر */
    val costTotal: Long get() = (quantity * costPrice).toLong()

    /** سود ناخالص این سطر (بعد از تخفیف، بدون مالیات) */
    val lineProfit: Long get() = netAmount - costTotal

    /** مبلغ قبل از تخفیف */
    val grossAmount: Long get() = (quantity * unitPrice).toLong()
    val discountAmount: Long get() = (grossAmount * discountPercent / 100.0).toLong()
    /** مبلغ بعد از تخفیف (مبنای مالیات) */
    val netAmount: Long get() = grossAmount - discountAmount
    val taxAmount: Long get() = (netAmount * taxPercent / 100.0).toLong()
    /** مبلغ نهایی سطر (با مالیات) */
    val lineTotal: Long get() = netAmount + taxAmount
}

data class Invoice(
    val id: Long = 0,
    /** شماره خوانا: مثل F-1404-00012 */
    val number: String = "",
    val type: InvoiceType = InvoiceType.SALE,
    val customerId: Long? = null,
    val issueDate: Long = 0,
    val dueDate: Long? = null,
    val status: PaymentStatus = PaymentStatus.UNPAID,
    /** مجموع مبالغ پرداخت‌شده */
    val paidAmount: Long = 0,
    /** تخفیف کلی روی کل فاکتور (مبلغی) */
    val globalDiscount: Long = 0,
    val note: String = "",
    val terms: String = "",
    /** مسیر فایل تصویر امضای دیجیتال */
    val signaturePath: String? = null,
    // مقادیر محاسبه‌شده (cache برای گزارش‌گیری سریع)
    val subtotal: Long = 0,
    val discountTotal: Long = 0,
    val taxTotal: Long = 0,
    val grandTotal: Long = 0,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
) {
    /** معوق: سررسید گذشته و تسویه نشده */
    val isOverdue: Boolean
        get() = status != PaymentStatus.PAID && dueDate != null && dueDate < System.currentTimeMillis()

    val remainingAmount: Long get() = (grandTotal - paidAmount).coerceAtLeast(0)

    /** برچسب وضعیت با درنظرگرفتن معوق بودن */
    val statusLabel: String get() = if (isOverdue) "معوق" else status.faName
}

data class InvoiceWithDetails(
    val invoice: Invoice,
    val items: List<InvoiceItem>,
    val customer: Customer? = null,
)

/** قالب فاکتور دوره‌ای */
@Serializable
data class RecurringTemplate(
    val items: List<InvoiceItem> = emptyList(),
    val note: String = "",
    val terms: String = "",
)

data class RecurringInvoice(
    val id: Long = 0,
    val title: String,
    val customerId: Long? = null,
    val interval: RecurrenceInterval = RecurrenceInterval.MONTHLY,
    /** تاریخ شروع (epoch) */
    val startDate: Long,
    /** سر رسید بعدی (epoch) */
    val nextRunDate: Long,
    val active: Boolean = true,
    val template: RecurringTemplate = RecurringTemplate(),
)
