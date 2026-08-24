package com.modir.forushgah.domain.shipping

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/** Spec §32/§43.24–28: the tracking message template — exact strings,
 * automatic name/provider/code, leading zeros preserved, one message per
 * selected order (never combined). */
class GenerateTrackingMessageUseCaseTest {

    private val generate = GenerateTrackingMessageUseCase()

    @Test
    fun `post message with leading zeros kept exactly`() {
        val message = generate("جاوید", "پست", "00123456789")
        assertThat(message).isEqualTo(
            "جاوید عزیز،\n" +
                "سفارش شما تحویل پست شد.\n" +
                "کد رهگیری: 00123456789",
        )
    }

    @Test
    fun `tipax message with provider prefix code`() {
        val message = generate("جاوید", "تیپاکس", "TP987654321")
        assertThat(message).isEqualTo(
            "جاوید عزیز،\n" +
                "سفارش شما تحویل تیپاکس شد.\n" +
                "کد رهگیری: TP987654321",
        )
    }

    @Test
    fun `hyphenated codes survive intact`() {
        val message = generate("سارا", "پیام", "AB-00123456")
        assertThat(message).contains("کد رهگیری: AB-00123456")
    }

    @Test
    fun `multi selection generates one separate message per order`() {
        // Two orders of the SAME customer — each gets its own message; the
        // texts differ only by the tracking code (never merged).
        val first = generate("جاوید", "پست", "CODE-A")
        val second = generate("جاوید", "تیپاکس", "CODE-B")
        assertThat(first).contains("CODE-A")
        assertThat(first).doesNotContain("CODE-B")
        assertThat(second).contains("CODE-B")
        assertThat(second).doesNotContain("CODE-A")
        assertThat(first).isNotEqualTo(second)
    }

    @Test
    fun `template matches the spec exactly`() {
        val message = generate("{customerName}", "{shippingProvider}", "{trackingCode}")
        assertThat(message).isEqualTo(
            "{customerName} عزیز،\n" +
                "سفارش شما تحویل {shippingProvider} شد.\n" +
                "کد رهگیری: {trackingCode}",
        )
    }
}
