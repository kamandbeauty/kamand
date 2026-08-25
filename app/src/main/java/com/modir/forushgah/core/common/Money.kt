package com.modir.forushgah.core.common

import kotlin.math.roundToLong

/**
 * Money is the single source of truth for every monetary value in the app.
 *
 * IMPORTANT: We NEVER use Double/Float for money. [amountInToman] is a plain
 * Long representing whole Tomans (the smallest unit we track). All arithmetic
 * that can produce a fraction (percentages, splits) rounds explicitly and
 * predictably (half-up) so results are reproducible and auditable.
 *
 * This type is used everywhere in the domain layer instead of raw Long/Int,
 * so a developer can never "accidentally" add a price to a quantity.
 *
 * DESIGN NOTE — Money is a `@JvmInline value class` with EXACTLY ONE primary
 * constructor property (`amountInToman`) and NO implemented interfaces:
 * Room's KSP processor resolves value-class column types through its
 * value-class KType path, which expects exactly one underlying property and
 * no extra interface members. Keeping Money a clean single-property value
 * class (member operator functions are fine; the isPositive/isNegative/isZero
 * extensions live at file top level, outside the class) keeps that KType
 * resolution unambiguous. Do NOT add interfaces or extra constructor
 * properties to Money.
 */
@JvmInline
value class Money(val amountInToman: Long) {

    operator fun plus(other: Money): Money = Money(amountInToman + other.amountInToman)
    operator fun minus(other: Money): Money = Money(amountInToman - other.amountInToman)
    operator fun times(factor: Int): Money = Money(amountInToman * factor)
    operator fun times(factor: Long): Money = Money(amountInToman * factor)
    operator fun unaryMinus(): Money = Money(-amountInToman)

    /** Divides into [parts] equal Money values. Any remainder (from integer division)
     * is distributed one Toman at a time to the first installments so the sum always
     * equals the original amount exactly (no money is lost or created by rounding). */
    fun splitEvenly(parts: Int): List<Money> {
        require(parts > 0) { "parts must be > 0" }
        val base = amountInToman / parts
        val remainder = amountInToman % parts
        return List(parts) { index ->
            Money(base + if (index < remainder) 1 else 0)
        }
    }

    /** Returns `this * percent / 100`, rounded half-up to the nearest Toman. */
    fun percentOf(percent: Double): Money {
        val result = (amountInToman.toDouble() * percent / 100.0).roundToLong()
        return Money(result)
    }

    /** Applies this Money as a percentage against a [base] amount, e.g. commissionPercent.applyTo(gross). */
    fun applyPercentTo(base: Money): Money = base.percentOf(this.amountInToman.toDouble())

    fun coerceAtLeastZero(): Money = if (amountInToman < 0) ZERO else this

    operator fun compareTo(other: Money): Int = amountInToman.compareTo(other.amountInToman)

    /** Formats using Persian digits and thousands separators, e.g. ۱۲۳٬۴۵۶ تومان. */
    fun toPersianDisplayString(includeCurrencySuffix: Boolean = true): String {
        val formatted = PersianNumberFormatter.formatWithSeparators(amountInToman)
        return if (includeCurrencySuffix) "$formatted تومان" else formatted
    }

    companion object {
        val ZERO = Money(0L)

        fun sum(values: Iterable<Money>): Money =
            Money(values.sumOf { it.amountInToman })

        fun toman(amount: Long): Money = Money(amount)
    }
}

fun Iterable<Money>.sum(): Money = Money.sum(this)

// Extension properties — kept outside the class for API stability (call sites
// use `money.isPositive` etc. via these imports).
val Money.isPositive: Boolean get() = amountInToman > 0
val Money.isNegative: Boolean get() = amountInToman < 0
val Money.isZero: Boolean get() = amountInToman == 0L
