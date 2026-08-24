package com.modir.forushgah.core.common

/**
 * Converts Western digits to Persian digits and inserts Persian thousands
 * separators (٬). Used everywhere a number is shown in the Persian UI.
 */
object PersianNumberFormatter {

    private val persianDigits = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')

    fun toPersianDigits(input: String): String =
        buildString {
            for (ch in input) {
                if (ch.isDigit()) append(persianDigits[ch - '0']) else append(ch)
            }
        }

    fun formatWithSeparators(value: Long): String {
        val negative = value < 0
        val digits = kotlin.math.abs(value).toString()
        val grouped = StringBuilder()
        for ((index, ch) in digits.reversed().withIndex()) {
            if (index != 0 && index % 3 == 0) grouped.append('٬')
            grouped.append(ch)
        }
        val result = grouped.reverse().toString()
        val withSign = if (negative) "-$result" else result
        return toPersianDigits(withSign)
    }
}
