package com.studiojavid.memory.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.studiojavid.memory.data.repo.TaskRepository

/** Re-arms all pending reminders (after reboot, app update or a restore). */
class RescheduleWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result = try {
        Notifications.ensureChannel(applicationContext)
        TaskRepository(applicationContext).rescheduleAllReminders()
        com.studiojavid.memory.data.repo.BirthdayRepository(applicationContext).rescheduleAll()
        ListenableWorker.Result.success()
    } catch (t: Throwable) {
        ListenableWorker.Result.retry()
    }
}
