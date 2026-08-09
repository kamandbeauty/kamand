package ir.factoryar.core.common.jalali

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/**
 * تبدیل دقیق تاریخ جلالی ↔ میلادی.
 * پیاده‌سازی الگوریتم jalaali (بر پایه‌ی محاسبات اخترشناختی چرخه‌های ۳۳ ساله).
 * استفاده از این نسخه به‌جای وابستگی خارجی، حجم APK را کم و آفلاین بودن را تضمین می‌کند.
 */
object JalaliConverter {

    private val breaks = intArrayOf(
        -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210,
        1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178
    )

    private fun div(a: Int, b: Int): Int = Math.floorDiv(a, b)
    private fun mod(a: Int, b: Int): Int = Math.floorMod(a, b)

    private data class JalCal(val leap: Int, val gy: Int, val march: Int)

    private fun jalCal(jy: Int): JalCal {
        val gy = jy + 621
        var leapJ = -14
        var jp = breaks[0]
        var jump = 0
        for (i in 1 until breaks.size) {
            val jm = breaks[i]
            jump = jm - jp
            if (jy < jm) break
            leapJ += div(jump, 33) * 8 + div(mod(jump, 33), 4)
            jp = jm
        }
        var n = jy - jp
        leapJ += div(n, 33) * 8 + div(mod(n, 33) + 3, 4)
        if (mod(jump, 33) == 4 && jump - n == 4) leapJ++
        val leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150
        val march = 20 + leapJ - leapG
        if (jump - n < 6) n = n - jump + div(jump + 4, 33) * 33
        var leap = mod(mod(n + 1, 33) - 1, 4)
        if (leap == -1) leap = 4
        return JalCal(leap, gy, march)
    }

    /**
     * روز ژولینی (JDN) از تاریخ میلادی — الگوریتم استاندارد Fliegel–Van Flandern.
     *
     * توجه: نسخهٔ پیشین این تابع فرمول فشردهٔ دیگری داشت که برای ماه‌های
     * مارس تا دسامبر دقیقاً یک سال (۳۶۵ روز) خطا می‌داد و باعث می‌شد
     * تبدیل تاریخ ماه‌های نامعتبر مثل ۱۳ و ۱۷ تولید کند.
     */
    private fun g2d(gy: Int, gm: Int, gd: Int): Int {
        val a = div(14 - gm, 12)
        val y = gy + 4800 - a
        val m = gm + 12 * a - 3
        return gd + div(153 * m + 2, 5) + 365 * y +
            div(y, 4) - div(y, 100) + div(y, 400) - 32045
    }

    /** تاریخ میلادی (سه‌تایی year, month, day) از روز ژولینی */
    private fun d2g(jdn: Int): Triple<Int, Int, Int> {
        val a = jdn + 32044
        val b = div(4 * a + 3, 146097)
        val c = a - div(146097 * b, 4)
        val d = div(4 * c + 3, 1461)
        val e = c - div(1461 * d, 4)
        val m = div(5 * e + 2, 153)
        val gd = e - div(153 * m + 2, 5) + 1
        val gm = m + 3 - 12 * div(m, 10)
        val gy = 100 * b + d - 4800 + div(m, 10)
        return Triple(gy, gm, gd)
    }

    private fun j2d(jy: Int, jm: Int, jd: Int): Int {
        val r = jalCal(jy)
        return g2d(r.gy, 3, r.march) + (jm - 1) * 31 - div(jm, 7) * (jm - 7) + jd - 1
    }

    fun gregorianToJalali(gy: Int, gm: Int, gd: Int): JalaliDate {
        val jdn = g2d(gy, gm, gd)
        val gyOfJdn = d2g(jdn).first
        var jy = gyOfJdn - 621
        val r = jalCal(jy)
        val jdnFarvardin1 = g2d(gyOfJdn, 3, r.march)
        var k = jdn - jdnFarvardin1
        val jm: Int
        val jd: Int
        if (k >= 0) {
            if (k <= 185) {
                jm = 1 + div(k, 31)
                jd = mod(k, 31) + 1
                return JalaliDate(jy, jm, jd)
            }
            k -= 186
        } else {
            jy -= 1
            k += 179
            if (r.leap == 1) k += 1
        }
        jm = 7 + div(k, 30)
        jd = mod(k, 30) + 1
        return JalaliDate(jy, jm, jd)
    }

    /** @return Triple(year, month, day) میلادی */
    fun jalaliToGregorian(jy: Int, jm: Int, jd: Int): Triple<Int, Int, Int> = d2g(j2d(jy, jm, jd))

    fun isLeapYear(jy: Int): Boolean = jalCal(jy).leap == 0

    fun monthLength(jy: Int, jm: Int): Int = when {
        jm <= 6 -> 31
        jm <= 11 -> 30
        isLeapYear(jy) -> 30
        else -> 29
    }

    // ------------------------- کمکی برای epoch millis -------------------------

    fun fromEpochMillis(millis: Long): JalaliDate {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.timeInMillis = millis
        return gregorianToJalali(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH))
    }

    /** آغاز روز (00:00 به وقت محلی) تاریخ شمسی داده‌شده، بر‌حسب epoch millis */
    fun toEpochMillis(date: JalaliDate): Long {
        val (gy, gm, gd) = jalaliToGregorian(date.year, date.month, date.day)
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(gy, gm - 1, gd, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    /** روز هفته (۰=شنبه … ۶=جمعه) برای تاریخ شمسی */
    fun weekdayOf(date: JalaliDate): Int {
        val (gy, gm, gd) = jalaliToGregorian(date.year, date.month, date.day)
        val cal = GregorianCalendar(gy, gm - 1, gd)
        return cal.get(Calendar.DAY_OF_WEEK) % 7 // SATURDAY(7)->0, SUNDAY(1)->1, ..., FRIDAY(6)->6
    }

    fun today(): JalaliDate = fromEpochMillis(System.currentTimeMillis())
}
