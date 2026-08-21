package com.studiojavid.diary.notifications

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
import com.studiojavid.diary.core.util.PersianNumbers
import com.studiojavid.diary.MainActivity
import com.studiojavid.diary.R

object Notifications {

    /**
     * The app's only channel. Bump the id if its importance or sound ever
     * changes: Android freezes both at creation, so an existing install would
     * otherwise keep the old behaviour forever.
     *
     * IMPORTANCE_DEFAULT, not HIGH: a birthday days away is a gentle heads-up,
     * not something to interrupt whatever the user is doing.
     */
    const val BIRTHDAY_CHANNEL_ID = "diary_birthdays"

    /** Reserved id for the diagnostic notification. */
    private const val TEST_NOTIFICATION_ID = 999_999L

    /** Keeps the test notification clear of any person's id. */
    private const val BIRTHDAY_ID_OFFSET = 500_000L

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(BIRTHDAY_CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                BIRTHDAY_CHANNEL_ID,
                context.getString(R.string.notification_birthday_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(R.string.notification_birthday_channel_desc)
                enableLights(true)
                lightColor = 0xFFFF7EB6.toInt()
                enableVibration(true)
                setSound(
                    android.media.RingtoneManager
                        .getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
            }
        )
    }

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Birthday reminder, in the app's own branded layout.
     *
     * Ids are offset per person so two people sharing a day both get a
     * notification instead of the second overwriting the first.
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

    /**
     * Posts an immediate notification so the user can verify the whole chain
     * (channel + permission + OEM battery policy) without waiting for a real
     * birthday. It deliberately uses the same code path as a real reminder —
     * a test that took a shortcut would prove nothing.
     */
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS, conditional = true)
    fun showTest(context: Context) {
        ensureChannel(context)
        if (!hasPermission(context)) return

        val content = RemoteViews(context.packageName, R.layout.notification_reminder).apply {
            setTextViewText(R.id.notif_title, context.getString(R.string.notif_test))
            setTextViewText(R.id.notif_time, subtitle(context))
            setViewVisibility(R.id.notif_action, android.view.View.GONE)
        }

        val notification = NotificationCompat.Builder(context, BIRTHDAY_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6B6B.toInt())
            .setColorized(true)
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(context.getString(R.string.notif_test))
            .setCustomContentView(content)
            .setCustomBigContentView(content)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(context)
                .notify(TEST_NOTIFICATION_ID.toInt(), notification)
        }
    }

    /** Localized "now" line under the notification title. */
    private fun subtitle(context: Context): String {
        val persian = context.resources.configuration.locales[0].language != "en"
        val now = java.time.LocalTime.now()
        val time = PersianNumbers.twoDigits(now.hour, persian) + ":" +
            PersianNumbers.twoDigits(now.minute, persian)
        return context.getString(R.string.notification_now, time)
    }
}
