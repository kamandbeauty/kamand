package com.modir.forushgah.domain

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.sum
import org.junit.Test

class MoneyTest {

    @Test
    fun `plus and minus are exact`() {
        val a = Money(1_400_000)
        val b = Money(300_000)
        assertThat((a + b).amountInToman).isEqualTo(1_700_000)
        assertThat((a - b).amountInToman).isEqualTo(1_100_000)
    }

    @Test
    fun `percentOf rounds half-up to nearest toman`() {
        // 700,000 = 10,000,000 * 7%
        assertThat(Money(10_000_000).percentOf(7.0).amountInToman).isEqualTo(700_000)
        // 0.5 rounds up
        assertThat(Money(1).percentOf(50.0).amountInToman).isEqualTo(1L) // 0.5 -> rounds to 1
    }

    @Test
    fun `splitEvenly never loses or creates money`() {
        val total = Money(4_650_000)
        val parts = total.splitEvenly(4)
        assertThat(parts).hasSize(4)
        assertThat(parts.sumOf { it.amountInToman }).isEqualTo(total.amountInToman)
        // 4,650,000 / 4 = 1,162,500 exactly, so all parts should be equal
        assertThat(parts.all { it.amountInToman == 1_162_500L }).isTrue()
    }

    @Test
    fun `splitEvenly distributes remainder to first installments`() {
        val total = Money(10)
        val parts = total.splitEvenly(3) // 3,3,4 -> remainder 1 toman goes to first part
        assertThat(parts.sumOf { it.amountInToman }).isEqualTo(10)
        assertThat(parts[0].amountInToman).isEqualTo(4)
        assertThat(parts[1].amountInToman).isEqualTo(3)
        assertThat(parts[2].amountInToman).isEqualTo(3)
    }

    @Test
    fun `commission settlement scenario from spec matches exactly`() {
        // Spec section 16 example:
        // Gross 10,000,000, commission 7% -> 700,000, net 9,300,000
        // down payment 50% -> 4,650,000, remaining 4,650,000 over 4 installments -> 1,162,500 each
        val gross = Money(10_000_000)
        val commission = gross.percentOf(7.0)
        assertThat(commission.amountInToman).isEqualTo(700_000)

        val net = gross - commission
        assertThat(net.amountInToman).isEqualTo(9_300_000)

        val downPayment = net.percentOf(50.0)
        assertThat(downPayment.amountInToman).isEqualTo(4_650_000)

        val remaining = net - downPayment
        assertThat(remaining.amountInToman).isEqualTo(4_650_000)

        val installments = remaining.splitEvenly(4)
        assertThat(installments.sumOf { it.amountInToman }).isEqualTo(remaining.amountInToman)
        assertThat(installments.all { it.amountInToman == 1_162_500L }).isTrue()
    }

    @Test
    fun `real order profit scenario from spec matches exactly`() {
        // Spec section 22:
        // Sale 2,500,000; purchase cost 1,400,000; commission 175,000;
        // shipping 80,000; packaging 20,000 -> real profit 825,000
        val sale = Money(2_500_000)
        val cost = Money(1_400_000)
        val commission = Money(175_000)
        val shipping = Money(80_000)
        val packaging = Money(20_000)

        val realProfit = sale - cost - commission - shipping - packaging
        assertThat(realProfit.amountInToman).isEqualTo(825_000)
    }

    @Test
    fun `shipping margin scenario from spec matches exactly`() {
        // Spec section 11: product 800,000, shipping charged 70,000,
        // customer pays 870,000, actual shipping cost 55,000 -> margin +15,000
        val shippingCharged = Money(70_000)
        val actualShippingCost = Money(55_000)
        val margin = shippingCharged - actualShippingCost
        assertThat(margin.amountInToman).isEqualTo(15_000)
    }

    @Test
    fun `sum extension adds a list of Money correctly`() {
        val values = listOf(Money(1000), Money(2000), Money(2500))
        assertThat(values.sum().amountInToman).isEqualTo(5500)
    }

    @Test
    fun `coerceAtLeastZero clamps negative remainders`() {
        assertThat(Money(-500).coerceAtLeastZero().amountInToman).isEqualTo(0)
        assertThat(Money(500).coerceAtLeastZero().amountInToman).isEqualTo(500)
    }

    @Test
    fun `comparison operators work as expected`() {
        assertThat(Money(100) < Money(200)).isTrue()
        assertThat(Money(200) > Money(100)).isTrue()
        assertThat(Money(100) == Money(100)).isTrue()
    }
}
