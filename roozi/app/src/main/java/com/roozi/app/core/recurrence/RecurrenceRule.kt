package com.roozi.app.core.recurrence

import com.roozi.app.core.date.JalaliDate
import java.time.DayOfWeek
import java.time.LocalDate

/**
 * Repeat rule of a task.
 *
 * Stored in a single TEXT column so no schema change is needed when new kinds
 * are added. The wire format is intentionally tiny and human readable:
 *
 *   ""              -> None
 *   "DAILY"         -> every day
 *   "WEEKLY:1,3,5"  -> on those ISO weekdays (1 = Monday … 7 = Sunday)
 *   "MONTHLY"       -> same day number of the next month
 *   "EVERY:3"       -> every N days
 *
 * Monthly recurrence follows the **Jalali** month for Persian users, because
 * "روز اول هر ماه" means the first of the Solar month, not the Gregorian one.
 */
sealed interface RecurrenceRule {

    data object None : RecurrenceRule

    data object Daily : RecurrenceRule

    /** Repeats on the given weekdays. An empty set behaves like [Daily]. */
    data class Weekly(val days: Set<DayOfWeek>) : RecurrenceRule

    /** Same day-of-month in the next month (Jalali when [persian] is true). */
    data object Monthly : RecurrenceRule

    /** Every [days] days. */
    data class EveryNDays(val days: Int) : RecurrenceRule

    val isRepeating: Boolean get() = this != None

    fun serialize(): String = when (this) {
        None -> ""
        Daily -> "DAILY"
        Monthly -> "MONTHLY"
        is Weekly -> if (days.isEmpty()) "DAILY" else
            "WEEKLY:" + days.map { it.value }.sorted().joinToString(",")
        is EveryNDays -> "EVERY:${days.coerceAtLeast(1)}"
    }

    /**
     * The next date strictly after [from] on which this rule fires.
     * Returns null when the rule does not repeat.
     */
    fun nextAfter(from: LocalDate, persian: Boolean = true): LocalDate? = when (this) {
        None -> null
        Daily -> from.plusDays(1)
        is EveryNDays -> from.plusDays(days.coerceAtLeast(1).toLong())
        is Weekly -> {
            val targets = if (days.isEmpty()) DayOfWeek.entries.toSet() else days
            var cursor = from.plusDays(1)
            var guard = 0
            while (cursor.dayOfWeek !in targets && guard < 14) {
                cursor = cursor.plusDays(1)
                guard++
            }
            cursor
        }

        Monthly -> if (persian) {
            JalaliDate.fromLocalDate(from).plusMonths(1).toLocalDate()
        } else {
            from.plusMonths(1)
        }
    }

    companion object {
        fun parse(raw: String?): RecurrenceRule {
            val value = raw?.trim().orEmpty()
            if (value.isEmpty()) return None
            return when {
                value == "DAILY" -> Daily
                value == "MONTHLY" -> Monthly
                value.startsWith("WEEKLY:") -> {
                    val days = value.removePrefix("WEEKLY:")
                        .split(",")
                        .mapNotNull { it.trim().toIntOrNull() }
                        .filter { it in 1..7 }
                        .map { DayOfWeek.of(it) }
                        .toSet()
                    if (days.isEmpty()) None else Weekly(days)
                }

                value.startsWith("EVERY:") -> {
                    val n = value.removePrefix("EVERY:").trim().toIntOrNull()
                    if (n == null || n < 1) None else EveryNDays(n)
                }

                else -> None
            }
        }

        /** Weekday order used by the UI: Saturday first in Persian, Sunday first in English. */
        fun weekdayOrder(persian: Boolean): List<DayOfWeek> = if (persian) listOf(
            DayOfWeek.SATURDAY, DayOfWeek.SUNDAY, DayOfWeek.MONDAY, DayOfWeek.TUESDAY,
            DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY
        ) else listOf(
            DayOfWeek.SUNDAY, DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY,
            DayOfWeek.THURSDAY, DayOfWeek.FRIDAY, DayOfWeek.SATURDAY
        )
    }
}
