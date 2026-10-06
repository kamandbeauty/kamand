package com.ruby.factor_ruby

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Minimal, dependency-free daily reminder scheduler.
 *
 * - Uses inexact repeating alarms (`setRepeating`) — no exact-alarm
 *   permission needed, battery friendly.
 * - Notification permission (API 33+) is requested only when the user
 *   enables reminders; the grant result flows back to Dart.
 * - Reminder time is mirrored into native SharedPreferences so
 *   [BootReceiver] can re-arm the alarm after a reboot.
 */
object NotificationScheduler {

    const val CHANNEL = "app/notifications"
    private const val CHANNEL_ID = "daily_horoscope"
    private const val PREFS = "tale_man_notifications"
    private const val PREF_HOUR = "hour"
    private const val PREF_MINUTE = "minute"
    private const val PREF_ENABLED = "enabled"
    private const val ALARM_REQUEST_CODE = 4101
    private const val NOTIFICATION_ID = 4102
    private const val PERMISSION_REQUEST_CODE = 4103

    private var pendingPermissionResult: MethodChannel.Result? = null

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "یادآوری طالع روزانه",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "هر روز صبح، طالع امروزت را یادآوری می‌کند"
        }
        manager.createNotificationChannel(channel)
    }

    fun requestPermission(
        activity: android.app.Activity,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST_CODE,
        )
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(granted)
    }

    fun scheduleDaily(context: Context, hour: Int, minute: Int) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(PREF_HOUR, hour)
            .putInt(PREF_MINUTE, minute)
            .putBoolean(PREF_ENABLED, true)
            .apply()

        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = Intent(context, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(Calendar.getInstance())) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        // Inexact repeating: no SCHEDULE_EXACT_ALARM permission required.
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending,
        )
    }

    fun cancel(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(PREF_ENABLED, false).apply()
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = Intent(context, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pending)
    }

    fun rescheduleFromPrefs(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PREF_ENABLED, false)) return
        val hour = prefs.getInt(PREF_HOUR, 8)
        val minute = prefs.getInt(PREF_MINUTE, 0)
        scheduleDaily(context, hour, minute)
    }

    fun showDailyNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }
        ensureChannel(context)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPending = PendingIntent.getActivity(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("طالع امروزت آماده است")
            .setContentText("ببین امروز عشق، کار و شانس چه چیزی برایت دارند.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("ببین امروز عشق، کار و شانس چه چیزی برایت دارند."),
            )
            .setAutoCancel(true)
            .setContentIntent(tapPending)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission revoked — ignore gracefully.
        }
    }
}
