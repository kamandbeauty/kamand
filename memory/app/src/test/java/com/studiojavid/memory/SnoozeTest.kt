package com.studiojavid.memory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Snooze contract for the reminder notification's snooze action.
 *
 * Snoozing re-arms the *same* reminder id a fixed number of minutes out, so the
 * scheduler replaces the pending alarm instead of stacking a second one.
 */
private const val SNOOZE_MINUTES = 5

private fun snoozeAt(now: Long): Long = now + SNOOZE_MINUTES * 60_000L

class SnoozeTest {

    @Test
    fun snoozePushesTheReminderForwardByTheAdvertisedInterval() {
        val now = 1_700_000_000_000L
        assertEquals(now + 300_000L, snoozeAt(now))
    }

    @Test
    fun snoozeIsAlwaysInTheFuture() {
        // A non-positive delay would make the scheduler drop the WorkManager
        // backstop, leaving only the exact alarm.
        val now = System.currentTimeMillis()
        assertTrue(snoozeAt(now) > now)
    }

    @Test
    fun repeatedSnoozesAccumulate() {
        val now = 0L
        assertEquals(600_000L, snoozeAt(snoozeAt(now)))
    }
}
