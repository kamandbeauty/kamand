package com.forushyar.app.util

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Date
import java.util.Locale

/**
 * ابزارهای نمایش اعداد و تاریخ به‌صورت فارسی (شمارگان فارسی + تقویم شمسی).
 *
 * برای تقویم شمسی از android.icu استفاده می‌کنیم که از اندروید 7 به بعد روی
 * سیستم‌عامل موجود است؛ بنابراین نیازی به کتابخانه خارجی نیست.
 */
object FormatUtils {

    private val faSymbols = DecimalFormatSymbols(Locale("fa", "IR"))
    private val numberFormat = DecimalFormat("#,###", faSymbols)

    private val faDate = android.icu.text.SimpleDateFormat("yyyy/MM/dd", Locale("fa", "IR"))
    private val faTime = android.icu.text.SimpleDateFormat("HH:mm", Locale("fa", "IR"))
    private val faDateTime = android.icu.text.SimpleDateFormat("yyyy/MM/dd - HH:mm", Locale("fa", "IR"))

    /** 1234567 -> ۱٬۲۳۴٬۵۶۷ */
    fun formatNumber(value: Long): String = numberFormat.format(value)

    /** مبلغ به تومان */
    fun formatPrice(value: Long): String = "${formatNumber(value)} تومان"

    fun formatDate(millis: Long): String = faDate.format(Date(millis))

    fun formatTime(millis: Long): String = faTime.format(Date(millis))

    fun formatDateTime(millis: Long): String = faDateTime.format(Date(millis))
}
