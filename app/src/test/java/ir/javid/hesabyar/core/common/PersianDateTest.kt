package ir.javid.hesabyar.core.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.time.LocalDate

class PersianDateTest {
    @Test fun `known Persian new year is formatted correctly`() {
        assertEquals("۱۴۰۳/۰۱/۰۱", PersianDate.fromGregorian(LocalDate.of(2024, 3, 20)).toString())
    }

    @Test fun `jalali date has a reversible Gregorian conversion`() {
        val epoch = PersianDate.parse("۱۴۰۲/۱۲/۲۹")
        assertNotNull(epoch)
        assertEquals("۱۴۰۲/۱۲/۲۹", PersianDate.format(epoch!!))
    }

    @Test fun `amount parsing accepts Persian digits and stores rial`() {
        assertEquals(12_345_670L, PersianNumbers.parseDisplayedAmount("۱,۲۳۴,۵۶۷"))
    }
}
