package com.studiojavid.memory

import com.studiojavid.memory.core.date.JalaliDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * The "on this day" anniversary rule mirrored from MemoryRepository.
 *
 * A Jalali anniversary cannot be expressed in SQL, so the repository computes
 * the matching Gregorian days itself. The subtle case is 30 Esfand: it exists
 * only in a leap year, and sliding it onto the 29th would show a page from the
 * wrong day.
 */
private fun anniversaries(today: LocalDate, yearsBack: Int = 10): List<LocalDate> {
    val anniversary = JalaliDate.fromLocalDate(today)
    return (1..yearsBack).mapNotNull { back ->
        val year = anniversary.year - back
        if (anniversary.day <= JalaliDate.monthLength(year, anniversary.month)) {
            JalaliDate(year, anniversary.month, anniversary.day).toLocalDate()
        } else {
            null
        }
    }
}

class OnThisDayTest {

    @Test
    fun everyCandidateKeepsTheSameJalaliDayAndMonth() {
        val today = LocalDate.of(2026, 8, 20)
        val expected = JalaliDate.fromLocalDate(today)
        val results = anniversaries(today)

        assertEquals(10, results.size)
        results.forEach { date ->
            val j = JalaliDate.fromLocalDate(date)
            assertEquals(expected.month, j.month)
            assertEquals(expected.day, j.day)
        }
    }

    @Test
    fun candidatesAreStrictlyInThePast() {
        val today = LocalDate.of(2026, 8, 20)
        anniversaries(today).forEach { assertTrue(it.isBefore(today)) }
    }

    @Test
    fun yearsDescendOneByOne() {
        val today = LocalDate.of(2026, 8, 20)
        val thisYear = JalaliDate.fromLocalDate(today).year
        val years = anniversaries(today).map { JalaliDate.fromLocalDate(it).year }
        assertEquals((1..10).map { thisYear - it }, years)
    }

    @Test
    fun lastDayOfLeapEsfandSkipsCommonYears() {
        // 1403 is a leap year, so 30 Esfand 1403 exists.
        val leapDay = JalaliDate(1403, 12, 30)
        assertEquals(30, JalaliDate.monthLength(1403, 12))

        val results = anniversaries(leapDay.toLocalDate(), yearsBack = 8)
        // Only the leap years among 1395..1402 can host a 30 Esfand.
        val expectedYears = (1..8).map { 1403 - it }.filter { JalaliDate.monthLength(it, 12) == 30 }

        assertEquals(expectedYears, results.map { JalaliDate.fromLocalDate(it).year })
        assertTrue(results.size < 8)
        results.forEach { assertEquals(30, JalaliDate.fromLocalDate(it).day) }
    }

    @Test
    fun ordinaryEsfandDayIsNeverSkipped() {
        // 29 Esfand exists in every year, leap or not.
        val results = anniversaries(JalaliDate(1403, 12, 29).toLocalDate(), yearsBack = 8)
        assertEquals(8, results.size)
    }
}
