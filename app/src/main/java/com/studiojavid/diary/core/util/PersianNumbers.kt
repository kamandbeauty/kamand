package com.studiojavid.diary.core.util

/**
 * Digit shaping helpers. In the Persian locale every user-visible number
 * (times, dates, percentages, counters, streaks) is rendered with Persian digits.
 */
object PersianNumbers {

    private val PERSIAN_DIGITS = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')

    fun toPersian(input: String): String = buildString(input.length) {
        for (c in input) {
            if (c in '0'..'9') append(PERSIAN_DIGITS[c - '0']) else append(c)
        }
    }

    fun toLatin(input: String): String = buildString(input.length) {
        for (c in input) {
            val idx = PERSIAN_DIGITS.indexOf(c)
            when {
                idx >= 0 -> append('0' + idx)
                c in '٠'..'٩' -> append('0' + (c - '٠')) // Arabic-Indic
                else -> append(c)
            }
        }
    }

    /** Formats a number using the digits appropriate for [persian]. */
    fun format(value: Int, persian: Boolean): String =
        if (persian) toPersian(value.toString()) else value.toString()

    /** Two digit zero-padded number, e.g. 07 / ۰۷ */
    fun twoDigits(value: Int, persian: Boolean): String {
        val s = value.toString().padStart(2, '0')
        return if (persian) toPersian(s) else s
    }
}
