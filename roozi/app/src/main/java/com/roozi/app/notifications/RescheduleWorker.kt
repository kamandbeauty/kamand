package com.roozi.app.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.roozi.app.data.repo.TaskRepository

/** Re-arms all pending reminders (after reboot, app update or a restore). */
class RescheduleWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result = try {
        Notifications.ensureChannel(applicationContext)
        TaskRepository(applicationContext).rescheduleAllReminders()
        ListenableWorker.Result.success()
    } catch (t: Throwable) {
        ListenableWorker.Result.retry()
    }
}
