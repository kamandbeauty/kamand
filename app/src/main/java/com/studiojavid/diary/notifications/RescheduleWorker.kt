package com.studiojavid.diary.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.studiojavid.diary.data.repo.BirthdayRepository

/**
 * Re-arms every birthday alarm after a reboot or an app update.
 *
 * Android clears all pending alarms on reboot, and a birthday reminder that
 * silently stopped existing is worse than one that never existed: the user is
 * relying on it precisely because they will not remember the date themselves.
 *
 * Run through WorkManager rather than directly in [BootReceiver] so the work
 * survives the receiver's short execution window and is retried if it fails.
 */
class RescheduleWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result = try {
        BirthdayRepository(applicationContext).rescheduleAll()
        ListenableWorker.Result.success()
    } catch (t: Throwable) {
        ListenableWorker.Result.retry()
    }
}
