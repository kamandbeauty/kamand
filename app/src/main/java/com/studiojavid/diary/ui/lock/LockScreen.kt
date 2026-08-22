package com.studiojavid.diary.ui.lock

import android.content.Intent
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.studiojavid.diary.R
import com.studiojavid.diary.ui.theme.DiaryTheme
import com.studiojavid.diary.ui.theme.timeOfDayGradient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * App-wide lock controller.
 *
 * Owns a single boolean — is the gate currently unlocked? The UI reads
 * [isUnlocked] to decide whether to draw the app or the lock screen.
 *
 * Life cycle:
 *  - [lock] is called when the Activity goes to the background (if the user
 *    chose "lock immediately"), or whenever anything needs to force-relock
 *    (e.g. the user enables the lock while the app is open).
 *  - [requestUnlock] is called by the lock screen once, on first composition,
 *    and again whenever the user taps the retry button.
 */
class AppLock {

    private val _isUnlocked = MutableStateFlow(false)
    val isUnlocked: StateFlow<Boolean> = _isUnlocked.asStateFlow()

    fun lock() {
        _isUnlocked.value = false
    }

    fun unlock() {
        _isUnlocked.value = true
    }
}

@Composable
fun LockScreen(
    appLock: AppLock,
    modifier: Modifier = Modifier,
) {
    val activity = LocalContext.current as? FragmentActivity ?: return
    val colors = DiaryTheme.colors

    var status by remember { mutableStateOf<BiometricGate.AuthResult?>(null) }
    var authTrigger by remember { mutableStateOf(0) }

    val canAuth = remember(activity) { BiometricGate.canAuthenticate(activity) }

    // Prompt automatically the first time this screen composes. Tapping the
    // retry button increments `authTrigger`, which re-runs the auth flow.
    // We skip the auto-prompt if no authenticator is enrolled/hardware missing
    // so the user can read the message and tap Settings instead.
    LaunchedEffect(authTrigger) {
        if (canAuth != BiometricManager.BIOMETRIC_SUCCESS && authTrigger == 0) {
            status = BiometricGate.AuthResult.Unavailable(canAuth)
            return@LaunchedEffect
        }
        val result = BiometricGate.authenticate(
            activity = activity,
            title = activity.getString(R.string.lock_title),
            subtitle = activity.getString(R.string.lock_subtitle),
        )
        status = result
        if (result is BiometricGate.AuthResult.Success) appLock.unlock()
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors.timeOfDayGradient(10))),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(28.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(88.dp)
                    .clip(CircleShape)
                    .background(colors.tint(colors.coral)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Rounded.Lock,
                    contentDescription = null,
                    tint = colors.onTint(colors.coral),
                    modifier = Modifier.size(38.dp)
                )
            }
            Spacer(Modifier.height(22.dp))
            Text(
                stringResource(R.string.lock_title),
                style = MaterialTheme.typography.headlineSmall,
                color = colors.textPrimary,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
            Text(
                when (status) {
                    is BiometricGate.AuthResult.Failed -> stringResource(R.string.lock_retry)
                    is BiometricGate.AuthResult.Cancelled -> stringResource(R.string.lock_tap_to_unlock)
                    is BiometricGate.AuthResult.Unavailable ->
                        if (canAuth == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED)
                            stringResource(R.string.lock_enroll_hint)
                        else
                            stringResource(R.string.lock_unavailable)
                    else -> stringResource(R.string.lock_subtitle)
                },
                style = MaterialTheme.typography.bodyMedium,
                color = colors.textSecondary,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(28.dp))

            Crossfade(targetState = status is BiometricGate.AuthResult.Unavailable, label = "lockActions") { unavailable ->
                if (unavailable) {
                    OutlinedButton(
                        onClick = {
                            runCatching {
                                activity.startActivity(
                                    Intent(Settings.ACTION_SECURITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            }
                        },
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.height(48.dp)
                    ) {
                        Text(stringResource(R.string.lock_open_settings))
                    }
                } else {
                    Button(
                        onClick = { authTrigger += 1 },
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = colors.coral,
                            contentColor = colors.onTint(colors.coral)
                        ),
                        modifier = Modifier.height(48.dp)
                    ) {
                        Text(stringResource(R.string.lock_unlock_button))
                    }
                }
            }
        }
    }
}
