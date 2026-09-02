package com.roozi.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/**
 * Mirrors TaskRepository.reminderTimestamp.
 *
 * These cases are regressions: reminders used to be discarded silently when a
 * task had no date, or when the default 09:00 had already passed, so the user
 * enabled a reminder and simply never got a notification.
 */
private const val DEFAULT_REMINDER_MINUTES = 9 * 60

private fun reminderTimestamp(
    date: LocalDate?,
    minutes: Int?,
    enabled: Boolean,
    now: Long,
    today: LocalDate
): Long? {
    if (!enabled) return null
    val zone = ZoneId.systemDefault()
    val day = date ?: today
    val m = minutes ?: DEFAULT_REMINDER_MINUTES

    var moment = day.atStartOfDay(zone).plusMinutes(m.toLong())
    if (moment.toInstant().toEpochMilli() <= now) {
        if (date == null || !day.isBefore(today)) moment = moment.plusDays(1) else return null
    }
    return moment.toInstant().toEpochMilli()
}

class ReminderTimingTest {

    private val zone = ZoneId.systemDefault()
    private val today = LocalDate.of(2026, 8, 15)

    private fun at(hour: Int, minute: Int, day: LocalDate = today): Long =
        day.atStartOfDay(zone).plusHours(hour.toLong()).plusMinutes(minute.toLong())
            .toInstant().toEpochMilli()

    @Test
    fun undatedTask_stillGetsAReminder() {
        val result = reminderTimestamp(null, null, enabled = true, now = at(7, 0), today = today)
        assertNotNull("an undated reminder must not be dropped", result)
        assertEquals(at(9, 0), result)
    }

    @Test
    fun defaultTimeAlreadyPassed_rollsToNextDay() {
        val result = reminderTimestamp(today, null, enabled = true, now = at(14, 0), today = today)
        assertNotNull(result)
        assertTrue("must be scheduled in the future", result!! > at(14, 0))
        assertEquals(at(9, 0, today.plusDays(1)), result)
    }

    @Test
    fun explicitFutureTime_isExact() {
        val result = reminderTimestamp(today, 18 * 60 + 30, true, at(14, 0), today)
        assertEquals(at(18, 30), result)
    }

    @Test
    fun futureDate_isHonouredExactly() {
        val tomorrow = today.plusDays(1)
        val result = reminderTimestamp(tomorrow, 10 * 60, true, at(14, 0), today)
        assertEquals(at(10, 0, tomorrow), result)
    }

    @Test
    fun explicitlyPastDate_hasNoReminder() {
        assertNull(reminderTimestamp(today.minusDays(3), 9 * 60, true, at(14, 0), today))
    }

    @Test
    fun disabled_isAlwaysNull() {
        assertNull(reminderTimestamp(today, null, enabled = false, now = at(7, 0), today = today))
    }
}
