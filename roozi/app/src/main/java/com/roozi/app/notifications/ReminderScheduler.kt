package com.roozi.app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.getSystemService
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

/**
 * Schedules task reminders.
 *
 * Two mechanisms are used together, deliberately:
 *
 *  1. **AlarmManager** — exact when the user has granted the capability,
 *     otherwise `setAndAllowWhileIdle`.
 *  2. **WorkManager** — a mirrored backstop for the same moment.
 *
 * The duplication exists because aggressive OEM battery managers (MIUI /
 * HyperOS in particular) frequently drop inexact alarms from apps that are not
 * whitelisted, which made reminders never arrive even with notification
 * permission granted. WorkManager survives those policies far better.
 * [Notifications.show] is idempotent per task id, so whichever path fires first
 * wins and the second is a no-op for the user.
 */
class ReminderScheduler(private val context: Context) {

    private val alarmManager: AlarmManager? = context.getSystemService()

    /** True when the OS lets us post exact alarms (always true below API 31). */
    fun canScheduleExact(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager?.canScheduleExactAlarms() == true

    fun schedule(taskId: Long, title: String, triggerAtMillis: Long) {
        scheduleAlarm(taskId, title, triggerAtMillis)
        scheduleWorkBackstop(taskId, triggerAtMillis)
    }

    private fun scheduleAlarm(taskId: Long, title: String, triggerAtMillis: Long) {
        val am = alarmManager ?: return
        val pending = pendingIntent(taskId, title)
        try {
            if (canScheduleExact()) {
                // setAlarmClock is the highest-priority alarm: it is exempt from
                // Doze and from most OEM throttling, which is what makes
                // reminders actually arrive on devices like Xiaomi.
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pending), pending)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }
        } catch (security: SecurityException) {
            // Exact-alarm capability revoked between the check and the call.
            Log.w(TAG, "Exact alarm denied, falling back to inexact", security)
            runCatching {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }.onFailure { Log.e(TAG, "Inexact alarm failed too", it) }
        } catch (t: Throwable) {
            Log.e(TAG, "Could not schedule alarm for task $taskId", t)
        }
    }

    /** Mirror of the alarm; harmless when the alarm already fired. */
    private fun scheduleWorkBackstop(taskId: Long, triggerAtMillis: Long) {
        val delay = triggerAtMillis - System.currentTimeMillis()
        if (delay <= 0) return
        runCatching {
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                workName(taskId),
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<ReminderWorker>()
                    .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                    .setInputData(workDataOf(ReminderWorker.KEY_TASK_ID to taskId))
                    .build()
            )
        }.onFailure { Log.e(TAG, "Could not enqueue reminder backstop", it) }
    }

    fun cancel(taskId: Long) {
        alarmManager?.let { am ->
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
        runCatching {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(workName(taskId))
        }
    }

    private fun pendingIntent(taskId: Long, title: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMIND
            // A unique data URI keeps PendingIntents distinct per task.
            data = android.net.Uri.parse("roozi://task/$taskId")
            putExtra(ReminderReceiver.EXTRA_TASK_ID, taskId)
            putExtra(ReminderReceiver.EXTRA_TITLE, title)
        }
        return PendingIntent.getBroadcast(
            context,
            taskId.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun workName(taskId: Long) = "roozi-reminder-$taskId"

    private companion object {
        const val TAG = "ReminderScheduler"
    }
}
