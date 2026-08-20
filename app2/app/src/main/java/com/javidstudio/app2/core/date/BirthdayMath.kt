package com.javidstudio.app2.core.date

import java.time.LocalDate

/**
 * Countdown and age arithmetic for birthdays, on the Jalali calendar.
 *
 * Birthdays are stored as a Jalali month/day (plus an optional birth year), not
 * as an absolute date: "25 Mordad" recurs every year, and the Gregorian date it
 * maps to drifts. Doing the maths in Jalali keeps the anniversary on the day the
 * user actually celebrates.
 *
 * Everything here is pure so it can be unit tested without Android.
 */
object BirthdayMath {

    /** Esfand 30 only exists in leap years; clamp to 29 otherwise. */
    fun clampToMonth(year: Int, month: Int, day: Int): Int =
        day.coerceAtMost(JalaliDate.monthLength(year, month))

    /**
     * The next occurrence of [month]/[day] on or after [today].
     *
     * A birthday that already passed this year rolls to next year, and a
     * birthday today counts as today (not next year).
     */
    fun nextOccurrence(month: Int, day: Int, today: LocalDate = LocalDate.now()): LocalDate {
        val jToday = JalaliDate.fromLocalDate(today)

        val thisYear = JalaliDate(jToday.year, month, clampToMonth(jToday.year, month, day))
        if (!thisYear.toLocalDate().isBefore(today)) return thisYear.toLocalDate()

        val nextYear = jToday.year + 1
        return JalaliDate(nextYear, month, clampToMonth(nextYear, month, day)).toLocalDate()
    }

    /** Whole days until the next occurrence; 0 means today. */
    fun daysUntil(month: Int, day: Int, today: LocalDate = LocalDate.now()): Int =
        (nextOccurrence(month, day, today).toEpochDay() - today.toEpochDay()).toInt()

    /**
     * Age the person turns on their next birthday, or null when the birth year
     * is unknown. On the birthday itself this is the age they turn today.
     */
    fun ageAtNextBirthday(
        birthYear: Int?,
        month: Int,
        day: Int,
        today: LocalDate = LocalDate.now()
    ): Int? {
        if (birthYear == null || birthYear <= 0) return null
        val next = JalaliDate.fromLocalDate(nextOccurrence(month, day, today))
        val age = next.year - birthYear
        return if (age >= 0) age else null
    }

    /**
     * Current age in completed years, or null when unknown.
     * Useful for details screens ("is 47", vs "turns 48").
     */
    fun currentAge(
        birthYear: Int?,
        month: Int,
        day: Int,
        today: LocalDate = LocalDate.now()
    ): Int? {
        if (birthYear == null || birthYear <= 0) return null
        val jToday = JalaliDate.fromLocalDate(today)
        val hadBirthdayThisYear =
            jToday.month > month || (jToday.month == month && jToday.day >= day)
        val age = jToday.year - birthYear - if (hadBirthdayThisYear) 0 else 1
        return if (age >= 0) age else null
    }

    /**
     * When a reminder for this birthday should fire, given how many days before
     * the user wants it, at [hourOfDay] local time.
     *
     * Returns the moment for the *next* birthday that still has a future
     * reminder: if this year's reminder window has already passed, it targets
     * the following year rather than firing immediately or not at all.
     */
    fun reminderDate(
        month: Int,
        day: Int,
        daysBefore: Int,
        today: LocalDate = LocalDate.now()
    ): LocalDate {
        val next = nextOccurrence(month, day, today)
        val candidate = next.minusDays(daysBefore.toLong())
        if (!candidate.isBefore(today)) return candidate

        // This year's lead time is already gone — aim at next year's birthday.
        val jNext = JalaliDate.fromLocalDate(next)
        val followingYear = jNext.year + 1
        val following = JalaliDate(
            followingYear,
            month,
            clampToMonth(followingYear, month, day)
        ).toLocalDate()
        return following.minusDays(daysBefore.toLong())
    }
}
