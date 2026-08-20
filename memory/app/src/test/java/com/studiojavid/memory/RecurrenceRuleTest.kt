package com.studiojavid.memory

import com.studiojavid.memory.core.date.JalaliDate
import com.studiojavid.memory.core.recurrence.RecurrenceRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

class RecurrenceRuleTest {

    private val friday = LocalDate.of(2026, 8, 14) // 1405/05/23

    @Test
    fun serializeParse_roundTrips() {
        val rules = listOf(
            RecurrenceRule.None,
            RecurrenceRule.Daily,
            RecurrenceRule.Monthly,
            RecurrenceRule.Weekly(setOf(DayOfWeek.SATURDAY, DayOfWeek.MONDAY)),
            RecurrenceRule.EveryNDays(3)
        )
        rules.forEach { assertEquals(it, RecurrenceRule.parse(it.serialize())) }
    }

    @Test
    fun malformedInput_fallsBackToNone() {
        assertEquals(RecurrenceRule.None, RecurrenceRule.parse(null))
        assertEquals(RecurrenceRule.None, RecurrenceRule.parse(""))
        assertEquals(RecurrenceRule.None, RecurrenceRule.parse("garbage"))
        assertEquals(RecurrenceRule.None, RecurrenceRule.parse("EVERY:0"))
        assertEquals(RecurrenceRule.None, RecurrenceRule.parse("WEEKLY:"))
    }

    @Test
    fun daily_and_everyNDays() {
        assertEquals(LocalDate.of(2026, 8, 15), RecurrenceRule.Daily.nextAfter(friday))
        assertEquals(LocalDate.of(2026, 8, 17), RecurrenceRule.EveryNDays(3).nextAfter(friday))
        assertNull(RecurrenceRule.None.nextAfter(friday))
    }

    /** «ورزش» هر شنبه، دوشنبه و چهارشنبه */
    @Test
    fun weekly_onlyHitsSelectedDays_andAlwaysAdvances() {
        val days = setOf(DayOfWeek.SATURDAY, DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY)
        val rule = RecurrenceRule.Weekly(days)
        assertEquals(DayOfWeek.SATURDAY, rule.nextAfter(friday)!!.dayOfWeek)

        var cursor = friday
        repeat(40) {
            val next = rule.nextAfter(cursor)!!
            assertTrue("must move forward", next.isAfter(cursor))
            assertTrue("must be a selected weekday", next.dayOfWeek in days)
            cursor = next
        }
    }

    /** «پرداخت اجاره» روز اول هر ماه — ماهِ شمسی، نه میلادی. */
    @Test
    fun monthly_followsJalaliMonth() {
        var cursor = JalaliDate(1405, 1, 1).toLocalDate()
        repeat(24) {
            cursor = RecurrenceRule.Monthly.nextAfter(cursor)!!
            assertEquals(1, JalaliDate.fromLocalDate(cursor).day)
        }
    }

    @Test
    fun monthly_neverOverflowsShortMonths() {
        val esfand30 = JalaliDate(1403, 12, 30).toLocalDate() // leap year
        val next = JalaliDate.fromLocalDate(RecurrenceRule.Monthly.nextAfter(esfand30)!!)
        assertTrue(next.day <= next.lengthOfMonth)
    }

    /**
     * Mirrors TaskRepository.rollForwardIfRepeating: a task ticked off long
     * after its due date must resurface today or later, never in the past.
     */
    private fun rollForward(rule: RecurrenceRule, base: LocalDate, today: LocalDate): LocalDate {
        var next = rule.nextAfter(base)!!
        var guard = 0
        while (next.isBefore(today) && guard < 1200) {
            next = rule.nextAfter(next)!!
            guard++
        }
        return next
    }

    @Test
    fun neglectedRepeatingTask_catchesUpToTodayOrLater() {
        val today = LocalDate.of(2026, 8, 14)
        val stale = today.minusDays(90)
        val rules = listOf(
            RecurrenceRule.Daily,
            RecurrenceRule.EveryNDays(3),
            RecurrenceRule.Monthly,
            RecurrenceRule.Weekly(setOf(DayOfWeek.SATURDAY, DayOfWeek.MONDAY))
        )
        rules.forEach { rule ->
            val next = rollForward(rule, stale, today)
            assertTrue("${rule.serialize()} resurfaced in the past", !next.isBefore(today))
        }
    }

    @Test
    fun neglectedWeekly_keepsCorrectWeekday() {
        val today = LocalDate.of(2026, 8, 14)
        val rule = RecurrenceRule.Weekly(setOf(DayOfWeek.SATURDAY))
        val next = rollForward(rule, today.minusDays(400), today)
        assertTrue(!next.isBefore(today))
        assertEquals(DayOfWeek.SATURDAY, next.dayOfWeek)
    }

    @Test
    fun emptyWeekly_behavesLikeDaily() {
        assertEquals("DAILY", RecurrenceRule.Weekly(emptySet()).serialize())
    }
}
