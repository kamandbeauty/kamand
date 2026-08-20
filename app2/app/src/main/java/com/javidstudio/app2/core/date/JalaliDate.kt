package com.javidstudio.app2.core.date

import java.time.LocalDate

/**
 * A real Jalali (Solar Hijri) calendar date.
 *
 * The conversion is based on the astronomical 33-year cycle algorithm
 * (Borkowski / Khayyam), which is accurate for the range 1178..1633 Jalali
 * (1799..2254 Gregorian) — far beyond any practical use of this app.
 *
 * All conversions are pure and side-effect free so they can be unit tested.
 */
data class JalaliDate(val year: Int, val month: Int, val day: Int) : Comparable<JalaliDate> {

    init {
        require(month in 1..12) { "month must be 1..12 but was $month" }
        require(day in 1..31) { "day must be 1..31 but was $day" }
    }

    /** Number of days in this Jalali month (accounts for leap Esfand). */
    val lengthOfMonth: Int get() = monthLength(year, month)

    val isLeapYear: Boolean get() = isLeapYear(year)

    fun toLocalDate(): LocalDate = jalaliToGregorian(year, month, day)

    fun toEpochDay(): Long = toLocalDate().toEpochDay()

    fun withDay(newDay: Int): JalaliDate = JalaliDate(year, month, newDay.coerceIn(1, lengthOfMonth))

    fun plusMonths(delta: Int): JalaliDate {
        val total = (year * 12 + (month - 1)) + delta
        val y = Math.floorDiv(total, 12)
        val m = Math.floorMod(total, 12) + 1
        return JalaliDate(y, m, day.coerceAtMost(monthLength(y, m)))
    }

    fun plusDays(delta: Int): JalaliDate = fromLocalDate(toLocalDate().plusDays(delta.toLong()))

    /**
     * Day of week index where 0 = Saturday … 6 = Friday (Persian week order).
     */
    val dayOfWeekIndex: Int
        get() = persianDayOfWeek(toLocalDate())

    override fun compareTo(other: JalaliDate): Int {
        if (year != other.year) return year - other.year
        if (month != other.month) return month - other.month
        return day - other.day
    }

    companion object {
        fun now(): JalaliDate = fromLocalDate(LocalDate.now())

        fun fromEpochDay(epochDay: Long): JalaliDate = fromLocalDate(LocalDate.ofEpochDay(epochDay))

        fun fromLocalDate(date: LocalDate): JalaliDate = gregorianToJalali(date)

        /** 0 = Saturday … 6 = Friday */
        fun persianDayOfWeek(date: LocalDate): Int = (date.dayOfWeek.value + 1) % 7

        fun isLeapYear(jy: Int): Boolean = jalaliCalendarParams(jy).leap == 0

        fun monthLength(jy: Int, jm: Int): Int = when {
            jm <= 6 -> 31
            jm <= 11 -> 30
            isLeapYear(jy) -> 30
            else -> 29
        }

        // ---------------------------------------------------------------
        // Core algorithm
        // ---------------------------------------------------------------

        private val BREAKS = intArrayOf(
            -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210,
            1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178
        )

        private data class CalParams(val leap: Int, val gy: Int, val march: Int)

        /**
         * Determines the leap offset, the corresponding Gregorian year of
         * Farvardin 1st and the March day on which Farvardin 1st falls.
         *
         * Note: Kotlin's `/` and `%` on Int truncate toward zero, which is
         * exactly what this algorithm requires (do not replace with floorDiv).
         */
        private fun jalaliCalendarParams(jy: Int): CalParams {
            val gy = jy + 621
            var leapJ = -14
            var jp = BREAKS[0]
            require(jy in jp..BREAKS[BREAKS.size - 1]) { "Jalali year $jy is out of supported range" }

            var jump = 0
            for (i in 1 until BREAKS.size) {
                val jm = BREAKS[i]
                jump = jm - jp
                if (jy < jm) break
                leapJ += (jump / 33) * 8 + (jump % 33) / 4
                jp = jm
            }
            var n = jy - jp

            leapJ += (n / 33) * 8 + ((n % 33) + 3) / 4
            if ((jump % 33) == 4 && jump - n == 4) leapJ += 1

            val leapG = gy / 4 - ((gy / 100 + 1) * 3) / 4 - 150
            val march = 20 + leapJ - leapG

            if (jump - n < 6) n = n - jump + ((jump + 4) / 33) * 33
            var leap = (((n + 1) % 33) - 1) % 4
            if (leap == -1) leap = 4
            return CalParams(leap, gy, march)
        }

        /** Julian Day Number for a Gregorian date. */
        private fun gregorianToJdn(gy: Int, gm: Int, gd: Int): Long {
            val a = ((gm - 8) / 6).toLong()
            val y = gy.toLong() + a
            var jdn = ((y + 100100L) * 1461L) / 4L +
                (153L * ((gm + 9) % 12) + 2L) / 5L + gd.toLong() - 34840408L
            jdn = jdn - ((y + 100100L) / 100L) * 3L / 4L + 752L
            return jdn
        }

        private fun jdnToGregorian(jdn: Long): Triple<Int, Int, Int> {
            var j = 4L * jdn + 139361631L
            j += (((4L * jdn + 183187720L) / 146097L) * 3L / 4L) * 4L - 3908L
            val i = ((j % 1461L) / 4L) * 5L + 308L
            val gd = ((i % 153L) / 5L) + 1L
            val gm = ((i / 153L) % 12L) + 1L
            val gy = (j / 1461L) - 100100L + ((8L - gm) / 6L)
            return Triple(gy.toInt(), gm.toInt(), gd.toInt())
        }

        internal fun jalaliToGregorian(jy: Int, jm: Int, jd: Int): LocalDate {
            val p = jalaliCalendarParams(jy)
            val jdn = gregorianToJdn(p.gy, 3, p.march) +
                (jm - 1) * 31L - (jm / 7) * (jm - 7).toLong() + jd - 1L
            val (gy, gm, gd) = jdnToGregorian(jdn)
            return LocalDate.of(gy, gm, gd)
        }

        internal fun gregorianToJalali(date: LocalDate): JalaliDate {
            val gy = date.year
            val jdn = gregorianToJdn(gy, date.monthValue, date.dayOfMonth)
            var jy = gy - 621
            val p = jalaliCalendarParams(jy)
            var k = (jdn - gregorianToJdn(gy, 3, p.march)).toInt()

            if (k >= 0) {
                if (k <= 185) return JalaliDate(jy, 1 + k / 31, (k % 31) + 1)
                k -= 186
            } else {
                jy -= 1
                k += 179
                if (p.leap == 1) k += 1
            }
            return JalaliDate(jy, 7 + k / 30, (k % 30) + 1)
        }
    }
}
