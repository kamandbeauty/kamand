package ir.factoryar.core.common.util

import java.util.Locale

object PersianFormatter {

    private val persianDigits = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')

    /** تبدیل ارقام انگلیسی به فارسی */
    fun String.toPersianDigits(): String = buildString(length) {
        for (c in this@toPersianDigits) {
            append(if (c in '0'..'9') persianDigits[c - '0'] else c)
        }
    }

    fun toPersianDigits(text: String): String = text.toPersianDigits()

    /** ارقام فارسی/عربی → انگلیسی، حذف جداکننده هزارگان و نقطه اعشار فارسی (برای ورودی کاربر) */
    fun String.toEnglishDigits(): String = buildString(length) {
        for (c in this@toEnglishDigits) {
            when (c) {
                in persianDigits -> append(persianDigits.indexOf(c))
                '\u066B', '٫' -> append('.')
                '٬', ',', ' ' -> Unit // جداکننده هزارگان
                else -> append(c)
            }
        }
    }

    /** ورودی مبلغ (Long) با پشتیبانی ارقام فارسی */
    fun parseMoney(input: String): Long = input.toEnglishDigits().trim().toLongOrNull() ?: 0L

    fun parseDouble(input: String): Double = input.toEnglishDigits().trim().toDoubleOrNull() ?: 0.0

    /** 1234567 -> "۱٬۲۳۴٬۵۶۷" */
    fun formatMoney(amount: Long): String =
        String.format(Locale.US, "%,d", amount).replace(',', '٬').toPersianDigits()

    /** قالب پول با واحد (تومان / ریال) */
    fun formatMoneyWithUnit(amount: Long, unit: CurrencyUnit): String =
        "${formatMoney(amount)} ${unit.faName}"

    /** اعداد اعشاری (مثل تعداد) به صورت تمیز: 2.0 -> "۲" ، 2.5 -> "۲٫۵" */
    fun formatQuantity(q: Double): String {
        val text = if (q == q.toLong().toDouble()) q.toLong().toString()
        else String.format(Locale.US, "%.2f", q).trimEnd('0').trimEnd('.')
        return text.replace('.', '٫').toPersianDigits()
    }

    fun formatDateTime(millis: Long): String {
        val date = ir.factoryar.core.common.jalali.JalaliConverter.fromEpochMillis(millis)
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = millis
        val hour = cal.get(java.util.Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val minute = cal.get(java.util.Calendar.MINUTE).toString().padStart(2, '0')
        return "${date.format()} - $hour:$minute".toPersianDigits()
    }
}

enum class CurrencyUnit(val faName: String, val factor: Long) {
    TOMAN("تومان", 1L),
    RIAL("ریال", 10L);

    companion object {
        fun fromName(name: String?): CurrencyUnit = entries.firstOrNull { it.name == name } ?: TOMAN
    }
}
