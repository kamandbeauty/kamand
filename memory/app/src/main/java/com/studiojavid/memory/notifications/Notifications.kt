package com.studiojavid.memory.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.os.Build
import android.widget.RemoteViews
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.studiojavid.memory.core.util.PersianNumbers
import com.studiojavid.memory.MainActivity
import com.studiojavid.memory.R

object Notifications {

    /**
     * Bumped when channel settings change: Android freezes a channel's
     * importance and sound at creation, so an existing install would otherwise
     * keep the previous behaviour forever. v3 drops the alarm ringtone that the
     * full-screen alarm needed.
     */
    const val CHANNEL_ID = "memory_task_reminders_v3"

    private val LEGACY_CHANNEL_IDS = listOf("memory_task_reminders", "memory_task_reminders_v2")

    /**
     * Birthdays keep their own channel. They are a gentle heads-up days in
     * advance, not something to be woken up by, so they must not inherit the
     * task channel's alarm sound and full-screen treatment.
     */
    const val BIRTHDAY_CHANNEL_ID = "memory_birthdays"

    /** Reserved id for the diagnostic notification. */
    private const val TEST_NOTIFICATION_ID = 999_999L

    /** Keeps birthday notification ids clear of task ids. */
    private const val BIRTHDAY_ID_OFFSET = 500_000L

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
            // The default notification tone at notification volume. An alarm
            // ringtone would keep ringing at alarm volume and cut through Do
            // Not Disturb, which a reminder that is no longer full-screen has
            // no business doing.
            setSound(
                android.media.RingtoneManager
                    .getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
            )
        }
        manager.createNotificationChannel(channel)
        // Superseded channels would otherwise linger in system settings as
        // dead entries the user can still toggle.
        LEGACY_CHANNEL_IDS.forEach { old ->
            runCatching { manager.deleteNotificationChannel(old) }
        }

        if (manager.getNotificationChannel(BIRTHDAY_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    BIRTHDAY_CHANNEL_ID,
                    context.getString(R.string.notification_birthday_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = context.getString(R.string.notification_birthday_channel_desc)
                    enableLights(true)
                    lightColor = 0xFFFF7EB6.toInt()
                }
            )
        }
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
                data = android.net.Uri.parse("memory://complete/$taskId")
                putExtra(ReminderReceiver.EXTRA_TASK_ID, taskId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = PendingIntent.getBroadcast(
            context,
            (taskId + 2_000_000).toInt(),
            Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_SNOOZE
                data = android.net.Uri.parse("memory://snooze/$taskId")
                putExtra(ReminderReceiver.EXTRA_TASK_ID, taskId)
                putExtra(ReminderReceiver.EXTRA_TITLE, title)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Custom layout so the reminder carries the app's identity instead of
        // the system's default grey card. DecoratedCustomViewStyle is avoided:
        // it would re-add the system header around our own artwork.
        val content = RemoteViews(context.packageName, R.layout.notification_reminder).apply {
            setTextViewText(R.id.notif_title, title)
            setTextViewText(R.id.notif_time, subtitle(context))
            setTextViewText(R.id.notif_action, context.getString(R.string.action_done))
            setOnClickPendingIntent(R.id.notif_action, doneIntent)
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6B6B.toInt())
            .setColorized(true)
            // Text versions are still supplied: they are what shows on
            // wearables, Android Auto and any launcher that ignores custom views.
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(title)
            .setCustomContentView(content)
            .setCustomBigContentView(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .addAction(0, context.getString(R.string.alarm_snooze), snoozeIntent)
            .addAction(0, context.getString(R.string.action_done), doneIntent)

        runCatching {
            NotificationManagerCompat.from(context).notify(taskId.toInt(), builder.build())
        }
    }

    /**
     * Posts an immediate notification so the user can verify the whole chain
     * (channel + permission + OEM policy) without waiting for a real reminder.
     */
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS, conditional = true)
    fun showTest(context: Context) {
        show(context, TEST_NOTIFICATION_ID, context.getString(R.string.notif_test))
    }

    /**
     * Birthday reminder. Uses the same branded layout as task reminders but a
     * cake badge and its own id space, so a birthday and a task reminder can
     * both be on screen without overwriting each other.
     */
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS, conditional = true)
    fun showBirthday(context: Context, personId: Long, name: String, daysUntil: Int) {
        ensureChannel(context)
        if (!hasPermission(context)) return

        val persian = context.resources.configuration.locales[0].language != "en"
        val title: String
        val body: String
        if (daysUntil <= 0) {
            title = context.getString(R.string.notif_birthday_today_title, name)
            body = context.getString(R.string.notif_birthday_today_body)
        } else {
            title = context.getString(R.string.notif_birthday_soon_title, name)
            body = if (daysUntil == 1) {
                context.getString(R.string.notif_birthday_tomorrow_body)
            } else {
                context.getString(
                    R.string.notif_birthday_soon_body,
                    PersianNumbers.format(daysUntil, persian)
                )
            }
        }

        val contentIntent = PendingIntent.getActivity(
            context,
            (personId + BIRTHDAY_ID_OFFSET).toInt(),
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val content = RemoteViews(context.packageName, R.layout.notification_reminder).apply {
            setTextViewText(R.id.notif_title, title)
            setTextViewText(R.id.notif_time, body)
            setViewVisibility(R.id.notif_action, android.view.View.GONE)
        }

        val notification = NotificationCompat.Builder(context, BIRTHDAY_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6B6B.toInt())
            .setColorized(true)
            .setContentTitle(title)
            .setContentText(body)
            .setCustomContentView(content)
            .setCustomBigContentView(content)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        runCatching {
            NotificationManagerCompat.from(context)
                .notify((personId + BIRTHDAY_ID_OFFSET).toInt(), notification)
        }
    }

    /** Localized "now" line under the reminder title. */
    private fun subtitle(context: Context): String {
        val persian = context.resources.configuration.locales[0].language != "en"
        val now = java.time.LocalTime.now()
        val time = PersianNumbers.twoDigits(now.hour, persian) + ":" +
            PersianNumbers.twoDigits(now.minute, persian)
        return context.getString(R.string.notification_now, time)
    }

    fun dismiss(context: Context, taskId: Long) {
        runCatching { NotificationManagerCompat.from(context).cancel(taskId.toInt()) }
    }
}
