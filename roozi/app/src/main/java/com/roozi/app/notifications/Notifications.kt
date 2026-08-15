package com.roozi.app.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.roozi.app.MainActivity
import com.roozi.app.R

object Notifications {

    const val CHANNEL_ID = "roozi_task_reminders"

    /** Reserved id for the diagnostic notification. */
    private const val TEST_NOTIFICATION_ID = 999_999L

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.notification_channel_desc)
            enableLights(true)
            lightColor = 0xFFFF6B6B.toInt()
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Posts a reminder. The POST_NOTIFICATIONS permission is verified by
     * [hasPermission] before any notify() call; lint cannot follow that through
     * a helper, hence the explicit annotation.
     */
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS, conditional = true)
    fun show(context: Context, taskId: Long, title: String) {
        ensureChannel(context)
        if (!hasPermission(context)) return

        val contentIntent = PendingIntent.getActivity(
            context,
            taskId.toInt(),
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val doneIntent = PendingIntent.getBroadcast(
            context,
            (taskId + 1_000_000).toInt(),
            Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_COMPLETE
                data = android.net.Uri.parse("roozi://complete/$taskId")
                putExtra(ReminderReceiver.EXTRA_TASK_ID, taskId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6B6B.toInt())
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(title)
            .setStyle(NotificationCompat.BigTextStyle().bigText(title))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .addAction(0, context.getString(R.string.action_done), doneIntent)
            .build()

        runCatching { NotificationManagerCompat.from(context).notify(taskId.toInt(), notification) }
    }

    /**
     * Posts an immediate notification so the user can verify the whole chain
     * (channel + permission + OEM policy) without waiting for a real reminder.
     */
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS, conditional = true)
    fun showTest(context: Context) {
        show(context, TEST_NOTIFICATION_ID, context.getString(R.string.notif_test))
    }

    fun dismiss(context: Context, taskId: Long) {
        runCatching { NotificationManagerCompat.from(context).cancel(taskId.toInt()) }
    }
}
