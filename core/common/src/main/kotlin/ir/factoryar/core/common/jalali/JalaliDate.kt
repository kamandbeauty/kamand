package ir.factoryar.core.common.jalali

/** نمایش یک تاریخ شمسی */
data class JalaliDate(val year: Int, val month: Int, val day: Int) : Comparable<JalaliDate> {

    init {
        require(month in 1..12) { "ماه باید بین ۱ تا ۱۲ باشد" }
        require(day in 1..31) { "روز نامعتبر است" }
    }

    /** 1403/05/12 */
    fun format(separator: String = "/"): String =
        "$year$separator${month.toString().padStart(2, '0')}$separator${day.toString().padStart(2, '0')}"

    override fun compareTo(other: JalaliDate): Int = compareValuesBy(this, other, { it.year }, { it.month }, { it.day })

    companion object {
        val MONTH_NAMES = listOf(
            "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
            "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"
        )

        /** حرف اول روزهای هفته به ترتیب از شنبه */
        val WEEKDAY_LETTERS = listOf("ش", "ی", "د", "س", "چ", "پ", "ج")

        val WEEKDAY_NAMES = listOf("شنبه", "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه")

        fun monthName(month: Int): String = MONTH_NAMES.getOrElse(month - 1) { "" }
    }
}
