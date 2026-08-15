package com.roozi.app.ui.components

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.roozi.app.R
import com.roozi.app.ui.theme.RooziTheme

/**
 * Explains why the alarm-style reminder needs a permission the system will not
 * ask for on its own.
 *
 * Android 14 pre-grants USE_FULL_SCREEN_INTENT only to apps it classifies as
 * alarm or calling apps and offers no runtime dialog, so a silent jump to a
 * settings page would leave the user with no idea what they were being asked
 * for. MIUI adds a second switch on a different page, hence the extra line.
 */
@Composable
fun FullScreenAlarmDialog(
    xiaomi: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    val colors = RooziTheme.colors

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.alarm_permission_title)) },
        text = {
            Text(
                if (xiaomi) stringResource(R.string.alarm_permission_body_xiaomi)
                else stringResource(R.string.alarm_permission_body)
            )
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(stringResource(R.string.alarm_permission_open))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.alarm_permission_later))
            }
        },
        containerColor = colors.surface,
        titleContentColor = colors.textPrimary,
        textContentColor = colors.textSecondary
    )
}
