package com.forushyar.app.util

import java.util.Calendar

object DateUtils {

    /**
     * بازه‌ی [start, end] به‌صورت میلی‌ثانیه برای «امروز» در منطقه زمانی دستگاه.
     */
    fun todayRange(): LongRange {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.DAY_OF_YEAR, 1)
        val end = cal.timeInMillis - 1
        return start..end
    }
}
