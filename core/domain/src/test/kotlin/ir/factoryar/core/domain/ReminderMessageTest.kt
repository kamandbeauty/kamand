package ir.factoryar.core.domain

import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.ReminderMessageBuilder
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderMessageTest {

    private val money: (Long) -> String = { "$it تومان" }
    private val date: (Long) -> String = { "1404/05/01" }

    private fun invoice(number: String, total: Long, paid: Long = 0) = Invoice(
        id = 1,
        number = number,
        status = PaymentStatus.UNPAID,
        grandTotal = total,
        paidAmount = paid,
        dueDate = 1_000L,
    )

    @Test
    fun `متن یادآوری شامل نام مشتری و مبلغ بدهی است`() {
        val entry = DebtorEntry(
            customer = Customer(id = 1, name = "آقای رضایی"),
            totalDebt = 2_500_000,
            overdueAmount = 2_500_000,
            overdueInvoiceCount = 1,
            maxOverdueDays = 12,
            overdueInvoices = listOf(invoice("F-1404-00007", 2_500_000)),
        )
        val text = ReminderMessageBuilder.build(
            entry = entry,
            businessName = "فروشگاه کمند",
            businessPhone = "09120000000",
            formatMoney = money,
            formatDate = date,
        )
        assertTrue(text.contains("آقای رضایی"))
        assertTrue(text.contains("فروشگاه کمند"))
        assertTrue(text.contains("F-1404-00007"))
        assertTrue(text.contains("2500000 تومان"))
        assertTrue(text.contains("09120000000"))
    }

    @Test
    fun `وقتی فاکتور معوقی نیست فقط مانده کل ذکر می شود`() {
        val entry = DebtorEntry(
            customer = Customer(id = 2, name = "خانم احمدی"),
            totalDebt = 800_000,
            overdueAmount = 0,
            overdueInvoiceCount = 0,
            maxOverdueDays = 0,
        )
        val text = ReminderMessageBuilder.build(
            entry = entry,
            businessName = "",
            formatMoney = money,
            formatDate = date,
        )
        assertTrue(text.contains("خانم احمدی"))
        assertTrue(text.contains("800000 تومان"))
        assertFalse(text.contains("سررسید"))
    }

    @Test
    fun `بیش از پنج فاکتور خلاصه می شود`() {
        val invoices = (1..8).map { invoice("F-1404-0000$it", 100_000L * it) }
        val entry = DebtorEntry(
            customer = Customer(id = 3, name = "شرکت الف"),
            totalDebt = invoices.sumOf { it.remainingAmount },
            overdueAmount = invoices.sumOf { it.remainingAmount },
            overdueInvoiceCount = invoices.size,
            maxOverdueDays = 40,
            overdueInvoices = invoices,
        )
        val text = ReminderMessageBuilder.build(
            entry = entry,
            businessName = "شرکت ب",
            formatMoney = money,
            formatDate = date,
        )
        assertTrue(text.contains("3 فاکتور دیگر"))
        assertFalse(text.contains("F-1404-00008"))
    }

    @Test
    fun `نام خالی مشتری با عبارت جایگزین پر می شود`() {
        val entry = DebtorEntry(
            customer = Customer(id = 4, name = "   "),
            totalDebt = 50_000,
            overdueAmount = 0,
            overdueInvoiceCount = 0,
            maxOverdueDays = 0,
        )
        val text = ReminderMessageBuilder.build(entry, "", "", money, date)
        assertTrue(text.contains("مشتری گرامی"))
    }
}
