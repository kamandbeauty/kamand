package com.forushyar.app.util

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** بازکردن پیام آماده در واتساپ معمولی یا واتساپ بیزینس، بدون SDK یا وابستگی آنلاین. */
object WhatsAppLauncher {

    private val packages = listOf("com.whatsapp", "com.whatsapp.w4b")

    fun open(context: Context, phone: String, message: String): Boolean {
        val normalizedPhone = normalizeIranianPhone(phone)
        val target = buildString {
            append("https://wa.me/")
            append(normalizedPhone)
            append("?text=")
            append(Uri.encode(message))
        }

        return packages.any { packageName ->
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    setPackage(packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (_: ActivityNotFoundException) {
                false
            } catch (_: SecurityException) {
                false
            }
        }
    }

    /** شماره 09 یا +98 را به قالب بین‌المللی مورد انتظار wa.me تبدیل می‌کند. */
    private fun normalizeIranianPhone(phone: String): String {
        val digits = buildString {
            phone.forEach { character ->
                when (character) {
                    in '0'..'9' -> append(character)
                    in '۰'..'۹' -> append('0' + (character - '۰'))
                    in '٠'..'٩' -> append('0' + (character - '٠'))
                }
            }
        }
        return when {
            digits.startsWith("0098") -> digits.drop(2)
            digits.startsWith("98") -> digits
            digits.startsWith("0") -> "98${digits.drop(1)}"
            else -> digits
        }
    }
}
