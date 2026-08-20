package com.studiojavid.memory

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/**
 * The streak rule mirrored from TasksViewModel: consecutive days with at least
 * one completion, ending today or (grace period) yesterday.
 */
private fun streakOf(days: Set<LocalDate>, today: LocalDate): Int {
    var cursor = if (days.contains(today)) today else today.minusDays(1)
    if (!days.contains(cursor)) return 0
    var streak = 0
    while (days.contains(cursor)) {
        streak++
        cursor = cursor.minusDays(1)
    }
    return streak
}

class StreakTest {

    private val today = LocalDate.of(2026, 8, 14)

    @Test
    fun noCompletions_isZero() {
        assertEquals(0, streakOf(emptySet(), today))
    }

    @Test
    fun onlyToday_isOne() {
        assertEquals(1, streakOf(setOf(today), today))
    }

    @Test
    fun consecutiveDaysIncludingToday() {
        val days = (0..4).map { today.minusDays(it.toLong()) }.toSet()
        assertEquals(5, streakOf(days, today))
    }

    @Test
    fun yesterdayGracePeriod_keepsStreakAlive() {
        val days = (1..3).map { today.minusDays(it.toLong()) }.toSet()
        assertEquals(3, streakOf(days, today))
    }

    @Test
    fun gapBreaksStreak() {
        val days = setOf(today, today.minusDays(1), today.minusDays(3), today.minusDays(4))
        assertEquals(2, streakOf(days, today))
    }

    @Test
    fun staleCompletions_resetToZero() {
        val days = setOf(today.minusDays(5), today.minusDays(6))
        assertEquals(0, streakOf(days, today))
    }
}
