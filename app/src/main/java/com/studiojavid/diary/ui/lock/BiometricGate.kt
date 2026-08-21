package com.studiojavid.diary.ui.lock

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Thin wrapper around AndroidX Biometric that exposes a single
 * `authenticate(successOnSystemCredential = true)` suspend call.
 *
 * Authentication policy:
 *  - BIOMETRIC_WEAK covers fingerprint, face, iris as enrolled on the device.
 *  - DEVICE_CREDENTIAL lets the user fall back to their system PIN / pattern /
 *    password if no biometric hardware is present (or their finger isn't on the
 *    sensor). We intentionally do NOT implement our own PIN pad — the system
 *    credential is tied to the gatekeeper/thm and is never exposed to the app.
 *  - If neither is enrolled, `canAuthenticate` returns a status code we can use
 *    to nudge the user into Settings rather than showing a dead prompt.
 */
object BiometricGate {

    sealed class AuthResult {
        data object Success : AuthResult()
        data object Cancelled : AuthResult()
        data class Failed(val errorCode: Int, val message: CharSequence?) : AuthResult()
        data class Unavailable(val status: Int) : AuthResult()
    }

    fun canAuthenticate(context: Context): Int {
        val manager = BiometricManager.from(context)
        return manager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )
    }

    suspend fun authenticate(
        activity: FragmentActivity,
        title: String,
        subtitle: String? = null,
    ): AuthResult {
        val status = canAuthenticate(activity)
        if (status != BiometricManager.BIOMETRIC_SUCCESS) {
            return AuthResult.Unavailable(status)
        }

        return suspendCancellableCoroutine { cont ->
            val executor = ContextCompat.getMainExecutor(activity)
            val prompt = BiometricPrompt(
                activity,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        if (cont.isActive) cont.resume(AuthResult.Success)
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        // User cancelled or lockout — treat as non-fatal cancelled.
                        val cancelled = errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                            errorCode == BiometricPrompt.ERROR_CANCELED ||
                            errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON
                        if (cont.isActive) {
                            cont.resume(
                                if (cancelled) AuthResult.Cancelled
                                else AuthResult.Failed(errorCode, errString)
                            )
                        }
                    }

                    override fun onAuthenticationFailed() {
                        // Auth rejected by biometric — prompt stays up; do not resume yet.
                    }
                }
            )

            val builder = BiometricPrompt.PromptInfo.Builder()
                .setTitle(title)
                .setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_WEAK or
                        BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
            if (subtitle != null) builder.setSubtitle(subtitle)

            cont.invokeOnCancellation { runCatching { prompt.cancelAuthentication() } }
            prompt.authenticate(builder.build())
        }
    }
}
