package com.modir.forushgah.domain.shipping

import javax.inject.Inject

/**
 * Spec §31/§32: the customer tracking message. A dedicated domain use case —
 * never generated inside Compose. The customer name, provider and tracking
 * code are all taken from saved data (the seller never types the name).
 *
 * Template, exactly:
 * ```
 * {customerName} عزیز،
 * سفارش شما تحویل {shippingProvider} شد.
 * کد رهگیری: {trackingCode}
 * ```
 * The tracking code is a String passed through untouched — leading zeros,
 * letters and hyphens must survive (spec §21).
 */
class GenerateTrackingMessageUseCase @Inject constructor() {
    operator fun invoke(customerName: String, shippingProvider: String, trackingCode: String): String =
        "$customerName عزیز،\n" +
            "سفارش شما تحویل $shippingProvider شد.\n" +
            "کد رهگیری: $trackingCode"
}
