package ir.factoryar.core.domain.model

enum class InvoiceType(val faName: String, val defaultPrefix: String) {
    PROFORMA("پیش‌فاکتور", "PF"),
    SALE("فاکتور فروش", "F"),
    PURCHASE("فاکتور خرید", "K");

    companion object {
        fun fromName(name: String?): InvoiceType = entries.firstOrNull { it.name == name } ?: SALE
    }
}

enum class PaymentStatus(val faName: String) {
    UNPAID("پرداخت‌نشده"),
    PARTIAL("پرداخت جزئی"),
    PAID("پرداخت‌شده");

    companion object {
        fun fromName(name: String?): PaymentStatus = entries.firstOrNull { it.name == name } ?: UNPAID
    }
}

enum class RecurrenceInterval(val faName: String, val approxDays: Int) {
    WEEKLY("هفتگی", 7),
    MONTHLY("ماهانه", 30),
    YEARLY("سالانه", 365);

    companion object {
        fun fromName(name: String?): RecurrenceInterval = entries.firstOrNull { it.name == name } ?: MONTHLY
    }
}
