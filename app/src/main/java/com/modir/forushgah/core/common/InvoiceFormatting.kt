package com.modir.forushgah.core.common

/**
 * Rubi-faithful invoice formatting (Phase 3.1): the Rubi app renders money as
 * `1,234,567 تومان` — Persian digits with LATIN commas (its
 * `PersianNumberFormatter.formatCurrency`), not the ٬ separator used elsewhere
 * in this app. Invoice screens must look exactly like Rubi, so they use these
 * helpers instead of `Money.toPersianDisplayString()`.
 */
object InvoiceFormatting {

    /** `1234567` → `۱,۲۳,۵۶۷` (Persian digits, latin commas). */
    fun formatNumberWithCommas(amountInToman: Long): String {
        val negative = amountInToman < 0
        val digits = kotlin.math.abs(amountInToman).toString()
        val grouped = StringBuilder()
        for ((index, ch) in digits.reversed().withIndex()) {
            if (index != 0 && index % 3 == 0) grouped.append(',')
            grouped.append(ch)
        }
        val result = grouped.reverse().toString()
        return PersianNumberFormatter.toPersianDigits(if (negative) "-$result" else result)
    }

    /** Rubi's `formatCurrency`: `۱,۲۳۴,۵۶۷ تومان`. */
    fun formatCurrency(money: Money, unit: String = "تومان"): String =
        formatNumberWithCommas(money.amountInToman) + " " + unit

    /** The invoice table uses the currency without the unit word (Rubi strips ' تومان'). */
    fun formatCurrencyShort(money: Money): String = formatNumberWithCommas(money.amountInToman)

    /** Card number in 4-digit groups, LTR-safe: `6104 3310 0000 0000`. */
    fun formatCardGrouped(cardNumber: String): String {
        val digits = cardNumber.filter { it.isDigit() }
        return digits.chunked(4).joinToString(" ")
    }
}
