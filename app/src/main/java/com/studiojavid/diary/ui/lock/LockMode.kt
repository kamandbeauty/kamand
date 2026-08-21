package com.studiojavid.diary.ui.lock

/**
 * How the app is currently locked.
 *
 *  - NONE: the user has not turned on any lock (default).
 *  - BIOMETRIC: any installed biometric (fingerprint, face, iris); falls back to
 *    the device PIN/pattern/password through the Biometric prompt's
 *    setDeviceCredentialAllowed(). We never store our own copy of a PIN, so the
 *    user's device credential is the secret.
 *
 * PIN-only locks are deliberately not stored locally: a 4-digit PIN held in
 * SharedPreferences is either plaintext (useless as security) or hashed with a
 * key derived from nothing stronger than the PIN itself. Until we add a proper
 * Keystore-backed enrollment flow, BIOMETRIC is the only trustworthy option,
 * and it works on 99% of devices running API 24+ with some form of secure
 * lock screen.
 */
enum class LockMode {
    NONE,
    BIOMETRIC;

    val enabled: Boolean get() = this != NONE

    companion object {
        fun from(id: String?): LockMode =
            entries.firstOrNull { it.name == id } ?: NONE
    }
}
