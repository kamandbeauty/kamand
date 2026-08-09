package com.forushyar.app.util

/**
 * رقم‌های فارسی/عربی و جداکننده‌های رایج مبلغ را به عدد Long نامنفی تبدیل می‌کند.
 */
fun String.toNonNegativeLongOrNull(): Long? {
    val normalized = buildString {
        this@toNonNegativeLongOrNull.forEach { character ->
            when (character) {
                in '۰'..'۹' -> append('0' + (character - '۰'))
                in '٠'..'٩' -> append('0' + (character - '٠'))
                ',', '٬', '،', ' ', '\u00A0' -> Unit
                else -> append(character)
            }
        }
    }
    return normalized.takeIf { it.isNotBlank() }?.toLongOrNull()?.takeIf { it >= 0 }
}
