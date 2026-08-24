package com.modir.forushgah.domain

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.PersianNumberFormatter
import org.junit.Test

class PersianNumberFormatterTest {

    @Test
    fun `converts western digits to persian digits`() {
        assertThat(PersianNumberFormatter.toPersianDigits("12345")).isEqualTo("۱۲۳۴۵")
    }

    @Test
    fun `formats thousands separators correctly`() {
        assertThat(PersianNumberFormatter.formatWithSeparators(1_234_567)).isEqualTo("۱٬۲۳۴٬۵۶۷")
    }

    @Test
    fun `formats small numbers without separators`() {
        assertThat(PersianNumberFormatter.formatWithSeparators(500)).isEqualTo("۵۰۰")
    }

    @Test
    fun `formats negative numbers with leading minus`() {
        assertThat(PersianNumberFormatter.formatWithSeparators(-1500)).isEqualTo("-۱٬۵۰۰")
    }

    @Test
    fun `formats zero correctly`() {
        assertThat(PersianNumberFormatter.formatWithSeparators(0)).isEqualTo("۰")
    }
}
