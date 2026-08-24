package com.modir.forushgah.core.date

import com.modir.forushgah.core.common.PersianNumberFormatter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.TimeZone

/**
 * Jalali (Shamsi) date strings, exactly as the Rubi invoice app uses them:
 * the create screen prefills `yyyy/MM/dd` (e.g. 1405/06/02) and the preview
 * renders the same value with Persian digits. Time zone follows the device
 * locale, like the reference app.
 */
object JalaliDateFormatter {

    private val zone: ZoneId
        get() = TimeZone.getDefault().toZoneId()

    /** Today's Jalali date as `yyyy/MM/dd` (Latin digits) — the invoice date field value. */
    fun todayJalali(): String = formatJalali(JalaliDate.now(), persianDigits = false)

    /** Epoch millis → `yyyy/MM/dd`, Persian digits by default (preview rendering). */
    fun formatJalali(millis: Long, persianDigits: Boolean = true): String =
        formatJalali(
            JalaliDate.fromLocalDate(
                Instant.ofEpochMilli(millis).atZone(zone).toLocalDate(),
            ),
            persianDigits,
        )

    fun formatJalali(date: JalaliDate, persianDigits: Boolean = true): String {
        val text = "%04d/%02d/%02d".format(date.year, date.month, date.day)
        return if (persianDigits) PersianNumberFormatter.toPersianDigits(text) else text
    }

    /**
     * Parses `yyyy/MM/dd` Jalali text (Persian or Latin digits, any slashes)
     * to the start-of-day epoch millis. Returns null for anything invalid —
     * callers decide the fallback (invoice creation uses now, the tracking
     * screen keeps the day unshipped).
     */
    fun parseJalaliText(text: String): Long? {
        val parts = text.trim().split("/")
        if (parts.size != 3) return null
        val y = parts[0].trim().let { toEnglish(it).toIntOrNull() } ?: return null
        val m = parts[1].trim().let { toEnglish(it).toIntOrNull() } ?: return null
        val d = parts[2].trim().let { toEnglish(it).toIntOrNull() } ?: return null
        if (y !in 1300..1500 || m !in 1..12 || d !in 1..31) return null
        return try {
            val zone = TimeZone.getDefault().toZoneId()
            JalaliDate(y, m, d).toLocalDate().atStartOfDay(zone).toInstant().toEpochMilli()
        } catch (e: Exception) {
            null
        }
    }

    private fun toEnglish(s: String): String {
        val fa = '۰'..'۹'
        return s.map { if (it in fa) ('0' + (it - '۰')) else it }.joinToString("")
    }
}
