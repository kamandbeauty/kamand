package com.studiojavid.memory.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.studiojavid.memory.data.local.MemoryDatabase

/**
 * WorkManager backstop for a single reminder.
 *
 * AlarmManager is the primary path, but OEM battery managers routinely drop
 * alarms from non-whitelisted apps. This worker targets the same instant, and
 * because the notification is keyed by task id, whichever fires first wins and
 * the other becomes a silent no-op.
 */
class ReminderWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val taskId = inputData.getLong(KEY_TASK_ID, -1L)
        if (taskId <= 0) return ListenableWorker.Result.success()

        return try {
            val task = MemoryDatabase.get(applicationContext).taskDao().findById(taskId)
            if (task != null && !task.isCompleted && task.reminderEnabled) {
                Notifications.show(applicationContext, taskId, task.title)
            }
            ListenableWorker.Result.success()
        } catch (t: Throwable) {
            ListenableWorker.Result.retry()
        }
    }

    companion object {
        const val KEY_TASK_ID = "task_id"
    }
}
