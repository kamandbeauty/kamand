package ir.factoryar.core.common

import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * تست رگرسیون تبدیل تاریخ.
 *
 * پس‌زمینه: نسخهٔ اولیهٔ [JalaliConverter.g2d] فرمول فشرده‌ای داشت که برای
 * ماه‌های مارس تا دسامبر دقیقاً ۳۶۵ روز خطا می‌داد و ماه‌های نامعتبر مثل
 * ۱۳ و ۱۷ تولید می‌کرد. این تست‌ها تضمین می‌کنند آن باگ برنگردد.
 */
class JalaliRoundTripTest {

    @Test
    fun `round trip over two centuries`() {
        var checked = 0
        for (jy in 1300..1499) {
            for (jm in 1..12) {
                val monthLen = JalaliConverter.monthLength(jy, jm)
                // اول، وسط و آخر هر ماه
                for (jd in listOf(1, monthLen / 2, monthLen)) {
                    val original = JalaliDate(jy, jm, jd)
                    val (gy, gm, gd) = JalaliConverter.jalaliToGregorian(jy, jm, jd)
                    val back = JalaliConverter.gregorianToJalali(gy, gm, gd)
                    assertEquals("round-trip failed for $jy/$jm/$jd", original, back)
                    checked++
                }
            }
        }
        assertTrue("باید حداقل ۷۰۰۰ تاریخ بررسی شود", checked > 7_000)
    }

    /** هیچ تاریخی نباید ماه خارج از ۱..۱۲ یا روز خارج از ۱..۳۱ تولید کند */
    @Test
    fun `never produces invalid month or day`() {
        // پیمایش روزانه روی ۱۰ سال میلادی
        var (gy, gm, gd) = Triple(2020, 1, 1)
        repeat(3653) {
            val j = JalaliConverter.gregorianToJalali(gy, gm, gd)
            assertTrue("ماه نامعتبر ${j.month} برای $gy-$gm-$gd", j.month in 1..12)
            assertTrue("روز نامعتبر ${j.day} برای $gy-$gm-$gd", j.day in 1..31)
            assertTrue("روز از طول ماه بیشتر است", j.day <= JalaliConverter.monthLength(j.year, j.month))

            // روز بعد
            val daysInGMonth = when (gm) {
                1, 3, 5, 7, 8, 10, 12 -> 31
                4, 6, 9, 11 -> 30
                else -> if ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0) 29 else 28
            }
            gd++
            if (gd > daysInGMonth) { gd = 1; gm++ }
            if (gm > 12) { gm = 1; gy++ }
        }
    }

    /** نوروزهای شناخته‌شده — مبنای درستی کل تقویم */
    @Test
    fun `known nowruz dates`() {
        val nowruz = mapOf(
            1400 to Triple(2021, 3, 21),
            1401 to Triple(2022, 3, 21),
            1402 to Triple(2023, 3, 21),
            1403 to Triple(2024, 3, 20),
            1404 to Triple(2025, 3, 21),
            1405 to Triple(2026, 3, 21),
        )
        nowruz.forEach { (jy, g) ->
            assertEquals(
                "نوروز $jy",
                g,
                JalaliConverter.jalaliToGregorian(jy, 1, 1),
            )
            assertEquals(
                "معکوس نوروز $jy",
                JalaliDate(jy, 1, 1),
                JalaliConverter.gregorianToJalali(g.first, g.second, g.third),
            )
        }
    }

    /** روزهای متوالی میلادی باید به روزهای متوالی شمسی نگاشت شوند */
    @Test
    fun `consecutive days map consecutively`() {
        val start = JalaliConverter.gregorianToJalali(2025, 3, 19)
        val next = JalaliConverter.gregorianToJalali(2025, 3, 20)
        val afterNext = JalaliConverter.gregorianToJalali(2025, 3, 21)

        // ۱۴۰۳/۱۲/۲۹ → ۱۴۰۳/۱۲/۳۰ → ۱۴۰۴/۰۱/۰۱
        assertEquals(JalaliDate(1403, 12, 29), start)
        assertEquals(JalaliDate(1403, 12, 30), next)
        assertEquals(JalaliDate(1404, 1, 1), afterNext)
    }

    @Test
    fun `epoch millis round trip`() {
        for (jy in 1395..1410) {
            listOf(1 to 1, 6 to 31, 7 to 1, 12 to 29).forEach { (jm, jd) ->
                val date = JalaliDate(jy, jm, jd)
                val millis = JalaliConverter.toEpochMillis(date)
                assertEquals(date, JalaliConverter.fromEpochMillis(millis))
            }
        }
    }
}
