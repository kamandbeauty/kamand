package com.forushyar.app.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NumberUtilsTest {
    @Test
    fun `عدد فارسی تبدیل می‌شود`() {
        assertEquals(1_250_000L, "۱٬۲۵۰٬۰۰۰".toNonNegativeLongOrNull())
    }

    @Test
    fun `عدد عربی تبدیل می‌شود`() {
        assertEquals(9876L, "٩٨٧٦".toNonNegativeLongOrNull())
    }

    @Test
    fun `عدد لاتین با جداکننده تبدیل می‌شود`() {
        assertEquals(42_500L, "42,500".toNonNegativeLongOrNull())
    }

    @Test
    fun `مقدار منفی پذیرفته نمی‌شود`() {
        assertNull("-1".toNonNegativeLongOrNull())
    }

    @Test
    fun `متن نامعتبر پذیرفته نمی‌شود`() {
        assertNull("نامعتبر".toNonNegativeLongOrNull())
    }
}
