package com.roozi.app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.getSystemService

/**
 * Schedules exact-ish reminders with AlarmManager.
 *
 * We deliberately avoid requesting SCHEDULE_EXACT_ALARM (a sensitive permission
 * that stores reject for a to-do app): on Android 12+ we use
 * [AlarmManager.setAndAllowWhileIdle], which is delivered within a small window
 * and survives Doze — accurate enough for task reminders and permission-free.
 */
class ReminderScheduler(private val context: Context) {

    private val alarmManager: AlarmManager? = context.getSystemService()

    fun schedule(taskId: Long, title: String, triggerAtMillis: Long) {
        val am = alarmManager ?: return
        val pending = pendingIntent(taskId, title, mutable = false)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }
        }
    }

    fun cancel(taskId: Long) {
        val am = alarmManager ?: return
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMIND
            data = android.net.Uri.parse("roozi://task/$taskId")
        }
        val pending = PendingIntent.getBroadcast(
            context, taskId.toInt(), intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pending != null) {
            am.cancel(pending)
            pending.cancel()
        }
    }

    private fun pendingIntent(taskId: Long, title: String, mutable: Boolean): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMIND
            // A unique data URI keeps PendingIntents distinct per task.
            data = android.net.Uri.parse("roozi://task/$taskId")
            putExtra(ReminderReceiver.EXTRA_TASK_ID, taskId)
            putExtra(ReminderReceiver.EXTRA_TITLE, title)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, taskId.toInt(), intent, flags)
    }
}
