package ir.factoryar.core.domain.model

/** دسته هزینه — کاربر می‌تواند دسته دلخواه بسازد */
data class ExpenseCategory(
    val id: Long = 0,
    val name: String,
    val colorArgb: Long = 0xFF795548,
    /** دسته‌های پیش‌فرض قابل حذف نیستند */
    val isDefault: Boolean = false,
    val sortOrder: Int = 0,
) {
    companion object {
        /** دسته‌های پیش‌فرض که در اولین اجرا ساخته می‌شوند */
        val DEFAULTS: List<Pair<String, Long>> = listOf(
            "اجاره" to 0xFF5C6BC0,
            "حقوق و دستمزد" to 0xFF26A69A,
            "قبوض" to 0xFFFFA726,
            "حمل‌ونقل" to 0xFF8D6E63,
            "خرید ملزومات" to 0xFF7E57C2,
            "تبلیغات" to 0xFFEC407A,
            "مالیات و عوارض" to 0xFF78909C,
            "متفرقه" to 0xFF9E9E9E,
        )
    }
}

/** هزینه ثبت‌شده کسب‌وکار */
data class Expense(
    val id: Long = 0,
    val title: String,
    val amount: Long,
    val categoryId: Long? = null,
    val date: Long = 0,
    val note: String = "",
    /** مسیر تصویر رسید (اختیاری) */
    val attachmentPath: String? = null,
    val createdAt: Long = 0,
)

data class ExpenseWithCategory(
    val expense: Expense,
    val categoryName: String? = null,
    val categoryColor: Long = 0xFF9E9E9E,
)

/** جمع هزینه به تفکیک دسته (برای نمودار و گزارش) */
data class ExpenseByCategory(
    val categoryId: Long?,
    val categoryName: String,
    val total: Long,
    val count: Int,
)

/**
 * گزارش سود و زیان واقعی.
 * سود ناخالص = فروش − بهای تمام‌شده کالای فروش‌رفته (COGS)
 * سود خالص  = سود ناخالص − هزینه‌های عمومی
 */
data class ProfitReport(
    val from: Long,
    val to: Long,
    /** درآمد: جمع فاکتورهای فروش */
    val revenue: Long = 0,
    /** بهای تمام‌شده کالای فروش‌رفته */
    val costOfGoodsSold: Long = 0,
    /** جمع هزینه‌های عمومی ثبت‌شده */
    val operatingExpenses: Long = 0,
    val expensesByCategory: List<ExpenseByCategory> = emptyList(),
    /** سری زمانی: (شروع بازه) → سه‌گانه درآمد/هزینه/سود خالص */
    val series: List<ProfitPoint> = emptyList(),
) {
    val grossProfit: Long get() = revenue - costOfGoodsSold
    val netProfit: Long get() = grossProfit - operatingExpenses

    /** حاشیه سود خالص به درصد */
    val netMarginPercent: Double
        get() = if (revenue <= 0) 0.0 else netProfit * 100.0 / revenue

    val grossMarginPercent: Double
        get() = if (revenue <= 0) 0.0 else grossProfit * 100.0 / revenue
}

data class ProfitPoint(
    /** ابتدای بازه (روز یا ماه) */
    val bucketStart: Long,
    val label: String,
    val revenue: Long,
    val cost: Long,
    val expenses: Long,
) {
    val netProfit: Long get() = revenue - cost - expenses
}

/** بازه زمانی گزارش */
enum class ReportRange(val faName: String) {
    THIS_WEEK("این هفته"),
    THIS_MONTH("این ماه"),
    LAST_MONTH("ماه گذشته"),
    LAST_3_MONTHS("۳ ماه اخیر"),
    THIS_YEAR("امسال"),
    CUSTOM("بازه دلخواه"),
}
