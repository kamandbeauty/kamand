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
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * Schedules birthday reminders.
 *
 * Mirrors [ReminderScheduler]: an exact alarm plus a WorkManager backstop,
 * because OEM battery managers drop inexact alarms. Ids are offset so birthday
 * alarms can never collide with task alarms.
 */
class BirthdayScheduler(private val context: Context) {

    private val alarmManager: AlarmManager? = context.getSystemService()

    private fun canScheduleExact(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager?.canScheduleExactAlarms() == true

    fun schedule(
        personId: Long,
        name: String,
        date: LocalDate,
        daysBefore: Int,
        actualDaysUntil: Int
    ) {
        val triggerAt = date.atStartOfDay(ZoneId.systemDefault())
            .plusHours(NOTIFY_HOUR.toLong())
            .toInstant()
            .toEpochMilli()

        // If today's notify hour has already passed, the alarm would be in the
        // past; roll to the same time tomorrow so it still lands.
        val safeTrigger = if (triggerAt <= System.currentTimeMillis()) {
            triggerAt + TimeUnit.DAYS.toMillis(1)
        } else triggerAt

        scheduleAlarm(personId, name, safeTrigger, daysBefore, actualDaysUntil)
        scheduleWorkBackstop(personId, safeTrigger)
    }

    private fun scheduleAlarm(
        personId: Long,
        name: String,
        triggerAtMillis: Long,
        daysBefore: Int,
        actualDaysUntil: Int
    ) {
        val am = alarmManager ?: return
        val pending = pendingIntent(personId, name, daysBefore, actualDaysUntil)
        try {
            if (canScheduleExact()) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pending), pending)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }
        } catch (security: SecurityException) {
            runCatching {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }.onFailure { Log.e(TAG, "Birthday alarm failed", it) }
        } catch (t: Throwable) {
            Log.e(TAG, "Could not schedule birthday alarm for $personId", t)
        }
    }

    private fun scheduleWorkBackstop(personId: Long, triggerAtMillis: Long) {
        val delay = triggerAtMillis - System.currentTimeMillis()
        if (delay <= 0) return
        runCatching {
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                workName(personId),
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<BirthdayReminderWorker>()
                    .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                    .setInputData(workDataOf(BirthdayReminderWorker.KEY_PERSON_ID to personId))
                    .build()
            )
        }.onFailure { Log.e(TAG, "Could not enqueue birthday backstop", it) }
    }

    fun cancel(personId: Long) {
        alarmManager?.let { am ->
            val intent = Intent(context, BirthdayReceiver::class.java).apply {
                action = BirthdayReceiver.ACTION_BIRTHDAY
                data = android.net.Uri.parse("roozi://birthday/$personId")
            }
            val pending = PendingIntent.getBroadcast(
                context, requestCode(personId), intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) {
                am.cancel(pending)
                pending.cancel()
            }
        }
        runCatching {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(workName(personId))
        }
    }

    private fun pendingIntent(
        personId: Long,
        name: String,
        daysBefore: Int,
        actualDaysUntil: Int
    ): PendingIntent {
        val intent = Intent(context, BirthdayReceiver::class.java).apply {
            action = BirthdayReceiver.ACTION_BIRTHDAY
            data = android.net.Uri.parse("roozi://birthday/$personId")
            putExtra(BirthdayReceiver.EXTRA_PERSON_ID, personId)
            putExtra(BirthdayReceiver.EXTRA_NAME, name)
            putExtra(BirthdayReceiver.EXTRA_DAYS_BEFORE, daysBefore)
            putExtra(BirthdayReceiver.EXTRA_DAYS_UNTIL, actualDaysUntil)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode(personId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Offset keeps birthday request codes clear of task ones. */
    private fun requestCode(personId: Long): Int = (personId + REQUEST_OFFSET).toInt()

    private fun workName(personId: Long) = "roozi-birthday-$personId"

    private companion object {
        const val TAG = "BirthdayScheduler"
        const val NOTIFY_HOUR = 9
        const val REQUEST_OFFSET = 500_000L
    }
}
