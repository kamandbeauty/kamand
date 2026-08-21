package com.studiojavid.diary

import com.studiojavid.diary.core.date.JalaliDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class JalaliDateTest {

    @Test
    fun knownDates_convertCorrectly() {
        assertEquals(JalaliDate(1405, 5, 23), JalaliDate.fromLocalDate(LocalDate.of(2026, 8, 14)))
        assertEquals(LocalDate.of(2026, 8, 14), JalaliDate(1405, 5, 23).toLocalDate())
        assertEquals(LocalDate.of(2025, 3, 21), JalaliDate(1404, 1, 1).toLocalDate())
        assertEquals(LocalDate.of(2024, 3, 20), JalaliDate(1403, 1, 1).toLocalDate())
        assertEquals(JalaliDate(1399, 1, 1), JalaliDate.fromLocalDate(LocalDate.of(2020, 3, 20)))
    }

    @Test
    fun leapYears_areCorrect() {
        val expected = listOf(1395, 1399, 1403, 1408, 1412, 1416, 1420)
        val actual = (1395..1420).filter { JalaliDate.isLeapYear(it) }
        assertEquals(expected, actual)
        assertEquals(30, JalaliDate.monthLength(1403, 12))
        assertEquals(29, JalaliDate.monthLength(1404, 12))
        assertEquals(31, JalaliDate.monthLength(1404, 6))
        assertEquals(30, JalaliDate.monthLength(1404, 7))
    }

    @Test
    fun roundTrip_isStableAcrossCentury() {
        var d = LocalDate.of(1950, 1, 1)
        val end = LocalDate.of(2100, 1, 1)
        while (d.isBefore(end)) {
            val j = JalaliDate.fromLocalDate(d)
            assertEquals(d, j.toLocalDate())
            assertTrue(j.month in 1..12)
            assertTrue(j.day in 1..j.lengthOfMonth)
            d = d.plusDays(1)
        }
    }

    @Test
    fun lastDayOfEsfand_isFollowedByNowruz() {
        for (jy in 1380..1450) {
            val esfandLength = JalaliDate.monthLength(jy, 12)
            val last = JalaliDate(jy, 12, esfandLength).toLocalDate()
            val nowruz = JalaliDate(jy + 1, 1, 1).toLocalDate()
            assertEquals(1, nowruz.toEpochDay() - last.toEpochDay())
        }
    }

    @Test
    fun plusMonths_clampsDayLength() {
        assertEquals(JalaliDate(1404, 12, 29), JalaliDate(1404, 6, 31).plusMonths(6))
        assertEquals(JalaliDate(1405, 1, 15), JalaliDate(1404, 12, 15).plusMonths(1))
        assertEquals(JalaliDate(1403, 12, 15), JalaliDate(1404, 1, 15).plusMonths(-1))
    }

    @Test
    fun dayOfWeek_saturdayIsZero() {
        // 1405/5/23 == 2026-08-14 is a Friday -> index 6
        assertEquals(6, JalaliDate(1405, 5, 23).dayOfWeekIndex)
        // The next day is Saturday -> index 0
        assertEquals(0, JalaliDate(1405, 5, 24).dayOfWeekIndex)
    }
}
