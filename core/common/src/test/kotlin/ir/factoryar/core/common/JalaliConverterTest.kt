package ir.factoryar.core.common

import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JalaliConverterTest {

    @Test
    fun `gregorian to jalali known dates`() {
        // 2024-03-20 == 1403/01/01 (نوروز ۱۴۰۳)
        val nooruz = JalaliConverter.gregorianToJalali(2024, 3, 20)
        assertEquals(JalaliDate(1403, 1, 1), nooruz)

        // 2025-07-29 == 1404/05/07
        assertEquals(JalaliDate(1404, 5, 7), JalaliConverter.gregorianToJalali(2025, 7, 29))
    }

    @Test
    fun `jalali to gregorian roundtrip`() {
        val g = JalaliConverter.jalaliToGregorian(1403, 12, 30) // 1403 کبیسه است
        assertEquals(Triple(2025, 3, 20), g)

        val j = JalaliConverter.gregorianToJalali(2025, 3, 20)
        assertEquals(JalaliDate(1403, 12, 30), j)
    }

    @Test
    fun `leap years and month lengths`() {
        assertTrue(JalaliConverter.isLeapYear(1403))
        assertFalse(JalaliConverter.isLeapYear(1404))
        assertEquals(31, JalaliConverter.monthLength(1404, 1))
        assertEquals(30, JalaliConverter.monthLength(1404, 7))
        assertEquals(29, JalaliConverter.monthLength(1404, 12))
        assertEquals(30, JalaliConverter.monthLength(1403, 12))
    }
}
