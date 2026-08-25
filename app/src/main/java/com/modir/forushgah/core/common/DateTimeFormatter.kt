package com.modir.forushgah.core.common

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Formats epoch millis into Persian-digit dates for display. The app is
 * Persian-first (spec), so every date the user sees uses Persian digits —
 * same policy as [PersianNumberFormatter] for plain numbers.
 */
object DateTimeFormatter {

    private val datePattern = SimpleDateFormat("yyyy/MM/dd", Locale.forLanguageTag("fa-IR"))
    private val dateTimePattern = SimpleDateFormat("yyyy/MM/dd، HH:mm", Locale.forLanguageTag("fa-IR"))

    fun date(millis: Long): String = synchronized(datePattern) { datePattern.format(Date(millis)) }

    fun dateTime(millis: Long): String = synchronized(dateTimePattern) { dateTimePattern.format(Date(millis)) }
}
