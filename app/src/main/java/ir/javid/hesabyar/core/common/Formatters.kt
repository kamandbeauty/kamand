package ir.javid.hesabyar.core.common

import java.time.LocalDate
import java.util.Locale
import kotlin.math.abs

object PersianNumbers {
    private const val EN = "0123456789"
    private const val FA = "۰۱۲۳۴۵۶۷۸۹"
    private const val AR = "٠١٢٣٤٥٦٧٨٩"

    fun toPersian(value: String): String = buildString(value.length) {
        value.forEach { char -> append(if (char in EN) FA[EN.indexOf(char)] else char) }
    }

    /** Accepts Persian, Arabic, and Latin keyboard digits; safe for numeric form fields. */
    fun toEnglish(value: String): String = buildString(value.length) {
        value.forEach { char ->
            append(when (char) {
                in FA -> EN[FA.indexOf(char)]
                in AR -> EN[AR.indexOf(char)]
                '٬', ',' -> ','
                else -> char
            })
        }
    }

    fun amount(value: Long, currency: String = "TOMAN"): String {
        val units = if (currency == "TOMAN") value / 10 else value
        val label = if (currency == "TOMAN") "تومان" else "ریال"
        return "${toPersian("%,d".format(Locale.US, units))} $label"
    }

    fun amountWithoutCurrency(value: Long, currency: String = "TOMAN"): String =
        toPersian("%,d".format(Locale.US, if (currency == "TOMAN") value / 10 else value))

    /** Converts the user's displayed amount to rial, the database's canonical unit. */
    fun parseDisplayedAmount(raw: String, currency: String = "TOMAN"): Long? {
        val normalized = toEnglish(raw).replace(",", "").trim()
        val number = normalized.toLongOrNull() ?: return null
        return if (currency == "TOMAN") number * 10 else number
    }

    fun quantity(value: Double): String {
        val formatted = if (value % 1.0 == 0.0) value.toLong().toString() else "%.3f".format(Locale.US, value).trimEnd('0').trimEnd('.')
        return toPersian(formatted)
    }
}

data class JalaliDate(val year: Int, val month: Int, val day: Int) {
    override fun toString(): String = "%04d/%02d/%02d".format(Locale.US, year, month, day).let(PersianNumbers::toPersian)
}

/** Calendar conversion kept in the domain layer so neither UI nor database depends on locale APIs. */
object PersianDate {
    private val gDays = intArrayOf(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
    private val jDays = intArrayOf(31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29)

    fun today(): Long = LocalDate.now().toEpochDay()
    fun format(epochDay: Long): String = fromGregorian(LocalDate.ofEpochDay(epochDay)).toString()
    fun formatLong(epochDay: Long): String {
        val date = fromGregorian(LocalDate.ofEpochDay(epochDay))
        val names = listOf("فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند")
        return "${PersianNumbers.toPersian(date.day.toString())} ${names[date.month - 1]} ${PersianNumbers.toPersian(date.year.toString())}"
    }

    fun fromGregorian(date: LocalDate): JalaliDate {
        var gy = date.year - 1600
        val gm = date.monthValue - 1
        val gd = date.dayOfMonth - 1
        var gDayNo = 365 * gy + (gy + 3) / 4 - (gy + 99) / 100 + (gy + 399) / 400
        for (i in 0 until gm) gDayNo += gDays[i]
        if (gm > 1 && isGregorianLeap(gy + 1600)) gDayNo++
        gDayNo += gd
        var jDayNo = gDayNo - 79
        val jNp = jDayNo / 12053
        jDayNo %= 12053
        var jy = 979 + 33 * jNp + 4 * (jDayNo / 1461)
        jDayNo %= 1461
        if (jDayNo >= 366) {
            jy += (jDayNo - 1) / 365
            jDayNo = (jDayNo - 1) % 365
        }
        var i = 0
        while (i < 11 && jDayNo >= jDays[i]) { jDayNo -= jDays[i]; i++ }
        return JalaliDate(jy, i + 1, jDayNo + 1)
    }

    /** Parses yyyy/MM/dd in Persian or Latin digits. */
    fun parse(value: String): Long? {
        val parts = PersianNumbers.toEnglish(value).trim().split('/', '-', '.').map { it.trim() }
        if (parts.size != 3) return null
        val y = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        val d = parts[2].toIntOrNull() ?: return null
        if (m !in 1..12 || d !in 1..31) return null
        return toGregorian(JalaliDate(y, m, d))?.toEpochDay()
    }

    fun toGregorian(jalali: JalaliDate): LocalDate? {
        if (jalali.month !in 1..12 || jalali.day !in 1..31) return null
        var jy = jalali.year - 979
        val jm = jalali.month - 1
        val jd = jalali.day - 1
        var jDayNo = 365 * jy + (jy / 33) * 8 + ((jy % 33 + 3) / 4)
        for (i in 0 until jm) jDayNo += jDays[i]
        jDayNo += jd
        var gDayNo = jDayNo + 79
        var gy = 1600 + 400 * (gDayNo / 146097)
        gDayNo %= 146097
        var leap = true
        if (gDayNo >= 36525) {
            gDayNo--
            gy += 100 * (gDayNo / 36524)
            gDayNo %= 36524
            if (gDayNo >= 365) gDayNo++ else leap = false
        }
        gy += 4 * (gDayNo / 1461)
        gDayNo %= 1461
        if (gDayNo >= 366) {
            leap = false
            gDayNo--
            gy += gDayNo / 365
            gDayNo %= 365
        }
        var gm = 0
        while (gm < 11) {
            val days = if (gm == 1 && leap) 29 else gDays[gm]
            if (gDayNo < days) break
            gDayNo -= days
            gm++
        }
        return runCatching { LocalDate.of(gy, gm + 1, gDayNo + 1) }.getOrNull()
    }

    fun startOfMonth(epochDay: Long): Long {
        val date = fromGregorian(LocalDate.ofEpochDay(epochDay))
        return toGregorian(JalaliDate(date.year, date.month, 1))!!.toEpochDay()
    }

    private fun isGregorianLeap(year: Int) = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

sealed interface ValidationResult {
    data object Valid : ValidationResult
    data class Invalid(val message: String) : ValidationResult
}

fun validatePositiveAmount(amount: Long): ValidationResult = if (amount > 0) ValidationResult.Valid else ValidationResult.Invalid("مبلغ باید بیشتر از صفر باشد")
fun validateNonBlank(value: String, label: String): ValidationResult = if (value.trim().isNotEmpty()) ValidationResult.Valid else ValidationResult.Invalid("$label را وارد کنید")
