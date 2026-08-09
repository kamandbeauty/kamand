package ir.factoryar.core.common.util

import java.util.Calendar

object DateUtils {

    const val DAY_MILLIS: Long = 24L * 60 * 60 * 1000

    fun now(): Long = System.currentTimeMillis()

    fun startOfToday(): Long = startOfDay(now())

    fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = millis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    fun startOfMonthJalali(): Long {
        val today = ir.factoryar.core.common.jalali.JalaliConverter.today()
        val first = ir.factoryar.core.common.jalali.JalaliDate(today.year, today.month, 1)
        return ir.factoryar.core.common.jalali.JalaliConverter.toEpochMillis(first)
    }

    fun plusDays(millis: Long, days: Int): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = millis
        cal.add(Calendar.DAY_OF_YEAR, days)
        return cal.timeInMillis
    }

    /** n روز قبل (برای نمودار ۷ روز گذشته و…) */
    fun daysAgo(days: Int): Long = startOfDay(plusDays(now(), -days))

    /** آیا millis قبل از الان است؟ */
    fun isPast(millis: Long): Boolean = millis < now()
}
