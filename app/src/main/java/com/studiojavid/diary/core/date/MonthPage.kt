package com.studiojavid.diary.core.date

import java.time.LocalDate

/**
 * A single month of the calendar, abstracted over the Jalali/Gregorian systems
 * so the calendar UI works identically for both locales.
 */
data class MonthPage(
    val persian: Boolean,
    val jalaliYear: Int,
    val jalaliMonth: Int,
    val gregorianYear: Int,
    val gregorianMonth: Int
) {
    /** Number of days in this month. */
    val length: Int
        get() = if (persian) JalaliDate.monthLength(jalaliYear, jalaliMonth)
        else LocalDate.of(gregorianYear, gregorianMonth, 1).lengthOfMonth()

    val firstDay: LocalDate
        get() = if (persian) JalaliDate(jalaliYear, jalaliMonth, 1).toLocalDate()
        else LocalDate.of(gregorianYear, gregorianMonth, 1)

    val lastDay: LocalDate get() = firstDay.plusDays((length - 1).toLong())

    /** Blank cells before the 1st, given the locale's first weekday. */
    val leadingBlanks: Int
        get() = if (persian) JalaliDate.persianDayOfWeek(firstDay) else firstDay.dayOfWeek.value % 7

    fun dayNumberOf(date: LocalDate): Int =
        if (persian) JalaliDate.fromLocalDate(date).day else date.dayOfMonth

    fun dateOfDay(day: Int): LocalDate = firstDay.plusDays((day - 1).toLong())

    fun contains(date: LocalDate): Boolean = !date.isBefore(firstDay) && !date.isAfter(lastDay)

    fun plusMonths(delta: Int): MonthPage = if (persian) {
        val j = JalaliDate(jalaliYear, jalaliMonth, 1).plusMonths(delta)
        of(true, j.toLocalDate())
    } else {
        of(false, LocalDate.of(gregorianYear, gregorianMonth, 1).plusMonths(delta.toLong()))
    }

    /**
     * Stable, monotonically increasing index used as a pager key so that
     * swiping between months maps onto a simple integer axis.
     */
    val index: Int
        get() = if (persian) jalaliYear * 12 + (jalaliMonth - 1) else gregorianYear * 12 + (gregorianMonth - 1)

    companion object {
        fun of(persian: Boolean, date: LocalDate): MonthPage {
            val j = JalaliDate.fromLocalDate(date)
            return MonthPage(persian, j.year, j.month, date.year, date.monthValue)
        }

        fun fromIndex(persian: Boolean, index: Int): MonthPage {
            val y = index / 12
            val m = index % 12 + 1
            return if (persian) of(true, JalaliDate(y, m, 1).toLocalDate())
            else of(false, LocalDate.of(y, m, 1))
        }
    }
}
