package com.studiojavid.diary.core.date

import android.content.Context
import com.studiojavid.diary.R
import com.studiojavid.diary.core.util.PersianNumbers
import java.time.LocalDate

/**
 * Locale-aware date/time formatting.
 *
 * In Persian the app uses the Jalali calendar and Persian digits, in English
 * the Gregorian calendar with Latin digits. UI code never formats dates itself.
 */
class DateFormatter(private val context: Context, val persian: Boolean) {

    private val jalaliMonths by lazy { context.resources.getStringArray(R.array.jalali_months) }
    private val jalaliWeekdays by lazy { context.resources.getStringArray(R.array.jalali_weekdays) }
    private val jalaliWeekdaysShort by lazy { context.resources.getStringArray(R.array.jalali_weekdays_short) }
    private val gregorianMonths by lazy { context.resources.getStringArray(R.array.gregorian_months) }
    private val gregorianWeekdaysShort by lazy { context.resources.getStringArray(R.array.gregorian_weekdays_short) }

    fun digits(value: Int): String = PersianNumbers.format(value, persian)

    fun digits(text: String): String = if (persian) PersianNumbers.toPersian(text) else text

    /** Localized Jalali month names, Farvardin first. */
    fun jalaliMonthNames(): List<String> = jalaliMonths.toList()

    /** Weekday header labels for the calendar grid, in display order. */
    fun weekdayHeaders(): List<String> =
        if (persian) jalaliWeekdaysShort.toList() else gregorianWeekdaysShort.toList()

    /** Index of the given date inside a week row (0 = leftmost column in logical order). */
    fun weekColumnOf(date: LocalDate): Int =
        if (persian) JalaliDate.persianDayOfWeek(date) else date.dayOfWeek.value % 7

    fun monthTitle(month: MonthPage): String =
        if (persian) "${jalaliMonths[month.jalaliMonth - 1]} ${digits(month.jalaliYear)}"
        else "${gregorianMonths[month.gregorianMonth - 1]} ${month.gregorianYear}"

    /** e.g. «۲۳ مرداد ۱۴۰۵» or «14 August 2026» */
    fun fullDate(date: LocalDate): String = if (persian) {
        val j = JalaliDate.fromLocalDate(date)
        "${digits(j.day)} ${jalaliMonths[j.month - 1]} ${digits(j.year)}"
    } else {
        "${date.dayOfMonth} ${gregorianMonths[date.monthValue - 1]} ${date.year}"
    }

    /** e.g. «شنبه ۲۳ مرداد» */
    fun weekdayAndDate(date: LocalDate): String = if (persian) {
        val j = JalaliDate.fromLocalDate(date)
        "${jalaliWeekdays[j.dayOfWeekIndex]} ${digits(j.day)} ${jalaliMonths[j.month - 1]}"
    } else {
        val name = date.dayOfWeek.getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.ENGLISH)
        "$name, ${gregorianMonths[date.monthValue - 1]} ${date.dayOfMonth}"
    }

    /** Relative label: امروز / فردا / دیروز, otherwise a short date. */
    fun relativeDate(date: LocalDate, today: LocalDate = LocalDate.now()): String = when (date) {
        today -> context.getString(R.string.rel_today)
        today.plusDays(1) -> context.getString(R.string.rel_tomorrow)
        today.minusDays(1) -> context.getString(R.string.rel_yesterday)
        else -> shortDate(date)
    }

    /** e.g. «۲۳ مرداد» or «14 Aug» */
    fun shortDate(date: LocalDate): String = if (persian) {
        val j = JalaliDate.fromLocalDate(date)
        "${digits(j.day)} ${jalaliMonths[j.month - 1]}"
    } else {
        "${date.dayOfMonth} ${gregorianMonths[date.monthValue - 1].take(3)}"
    }

    /** Minutes since midnight -> «۱۸:۳۰» / «18:30» */
    fun time(minutesOfDay: Int): String {
        val h = (minutesOfDay / 60).coerceIn(0, 23)
        val m = (minutesOfDay % 60).coerceIn(0, 59)
        return PersianNumbers.twoDigits(h, persian) + ":" + PersianNumbers.twoDigits(m, persian)
    }

    /**
     * A recurring day/month with no year, e.g. «۲۵ مرداد».
     * Used for birthdays, which are anniversaries rather than absolute dates.
     */
    fun jalaliDayMonth(month: Int, day: Int): String {
        val safeMonth = month.coerceIn(1, 12)
        return if (persian) {
            "${digits(day)} ${jalaliMonths[safeMonth - 1]}"
        } else {
            "${digits(day)} ${jalaliMonths[safeMonth - 1]}"
        }
    }

    /** Full Jalali date including the year, e.g. «۲۵ مرداد ۱۳۶۳». */
    fun jalaliFull(year: Int, month: Int, day: Int): String {
        val safeMonth = month.coerceIn(1, 12)
        return "${digits(day)} ${jalaliMonths[safeMonth - 1]} ${digits(year)}"
    }

    fun percent(value: Int): String = context.getString(R.string.progress_percent, digits(value))
}
