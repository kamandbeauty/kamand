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

    /**
     * Room/KSP value-class rules — do NOT violate either:
     * 1. No interfaces on the class (e.g. `: Comparable<Money>`).
     * 2. The class body declares EXACTLY ONE property (`amountInToman`);
     *    `isPositive`/`isNegative`/`isZero` live OUTSIDE the class as
     *    extension properties below (same call sites: `money.isPositive`).
     * Room's KSP `getValueClassUnderlyingProperty` calls `properties.single()`
     * on value-class column types. NOTE: the crash that motivated rule 2 was
     * ultimately a KSP2 value-class/KType bug (Room could not match the
     * @TypeConverter, so it fell back to the default adapter) — the real fix
     * is `ksp.useKSP2=false` in gradle.properties. Rules 1-2 are kept anyway
     * because they are required for any version of Room that inspects
     * value-class properties directly.
     */
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

// Extension properties — intentionally OUTSIDE the value class body so Room/KSP
// sees exactly one declared property (see the rule above). Same call syntax.
val Money.isPositive: Boolean get() = amountInToman > 0
val Money.isNegative: Boolean get() = amountInToman < 0
val Money.isZero: Boolean get() = amountInToman == 0L
