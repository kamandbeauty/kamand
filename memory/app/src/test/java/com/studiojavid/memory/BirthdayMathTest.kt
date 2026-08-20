package com.studiojavid.memory

import com.studiojavid.memory.core.date.BirthdayMath
import com.studiojavid.memory.core.date.JalaliDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * Birthday countdown and age arithmetic.
 *
 * Birthdays are anniversaries on the Jalali calendar, so the maths has to cope
 * with a date that has already passed this year, with Esfand 30 existing only
 * in leap years, and with an unknown birth year.
 */
class BirthdayMathTest {

    /** 1405/05/24 */
    private val today = JalaliDate(1405, 5, 24).toLocalDate()

    @Test
    fun birthdayToday_isZeroDays() {
        assertEquals(0, BirthdayMath.daysUntil(5, 24, today))
    }

    @Test
    fun birthdayTomorrow_isOneDay() {
        assertEquals(1, BirthdayMath.daysUntil(5, 25, today))
    }

    @Test
    fun birthdayLaterThisMonth_countsForward() {
        assertEquals(3, BirthdayMath.daysUntil(5, 27, today))
    }

    @Test
    fun birthdayAlreadyPassed_rollsToNextYear() {
        val next = JalaliDate.fromLocalDate(BirthdayMath.nextOccurrence(1, 1, today))
        assertEquals(1406, next.year)
        assertEquals(1, next.month)
        assertEquals(1, next.day)
        assertTrue(BirthdayMath.daysUntil(1, 1, today) > 0)
    }

    @Test
    fun everyDayOfTheYear_staysInRange() {
        for (month in 1..12) {
            for (day in 1..JalaliDate.monthLength(1405, month)) {
                val days = BirthdayMath.daysUntil(month, day, today)
                assertTrue("daysUntil($month/$day) = $days", days in 0..366)
            }
        }
    }

    @Test
    fun ageOnBirthday_isTheAgeTheyTurn() {
        assertEquals(42, BirthdayMath.ageAtNextBirthday(1363, 5, 24, today))
        assertEquals(42, BirthdayMath.currentAge(1363, 5, 24, today))
    }

    @Test
    fun beforeBirthday_currentAgeIsOneLess() {
        assertEquals(41, BirthdayMath.currentAge(1363, 12, 1, today))
        assertEquals(42, BirthdayMath.ageAtNextBirthday(1363, 12, 1, today))
    }

    @Test
    fun withoutBirthYear_noAgeIsShown() {
        assertNull(BirthdayMath.ageAtNextBirthday(null, 5, 24, today))
        assertNull(BirthdayMath.currentAge(null, 5, 24, today))
        assertNull(BirthdayMath.ageAtNextBirthday(0, 5, 24, today))
    }

    @Test
    fun esfand30_clampsInNonLeapYears() {
        assertTrue(!JalaliDate.isLeapYear(1405))
        val next = JalaliDate.fromLocalDate(BirthdayMath.nextOccurrence(12, 30, today))
        assertEquals(12, next.month)
        assertTrue("day ${next.day} must fit in the month", next.day <= next.lengthOfMonth)
    }

    @Test
    fun leapDayPerson_neverProducesAnInvalidDate() {
        for (year in 1400..1440) {
            val from = JalaliDate(year, 1, 1).toLocalDate()
            val next = JalaliDate.fromLocalDate(BirthdayMath.nextOccurrence(12, 30, from))
            assertEquals(12, next.month)
            assertTrue(next.day <= next.lengthOfMonth)
        }
    }

    @Test
    fun reminderIsNeverScheduledInThePast() {
        for (offset in listOf(0, 1, 3, 7, 14)) {
            for (month in 1..12) {
                val date = BirthdayMath.reminderDate(month, 15, offset, today)
                assertTrue(
                    "reminder for $month/15 (-$offset) landed in the past",
                    !date.isBefore(today)
                )
            }
        }
    }

    @Test
    fun reminderLeadTimeIsHonoured() {
        // 3 days before a birthday that is 3 days away is today.
        assertEquals(today, BirthdayMath.reminderDate(5, 27, 3, today))
    }
}
