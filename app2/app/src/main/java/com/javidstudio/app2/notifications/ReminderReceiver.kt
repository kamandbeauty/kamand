package com.javidstudio.app2.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.javidstudio.app2.data.local.App2Database
import com.javidstudio.app2.data.repo.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Delivers reminders and handles the "Done" action straight from the shade.
 * Works while the app is closed — the alarm wakes this receiver up.
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L)
        if (taskId <= 0) return
        val appContext = context.applicationContext
        val pending = goAsync()
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

        scope.launch {
            try {
                when (intent.action) {
                    ACTION_COMPLETE -> {
                        TaskRepository(appContext).setCompleted(taskId, true)
                        Notifications.dismiss(appContext, taskId)
                    }

                    ACTION_SNOOZE -> {
                        // Title comes from the intent so snoozing still works
                        // if the row was edited in the meantime.
                        val title = intent.getStringExtra(EXTRA_TITLE)
                            ?: App2Database.get(appContext).taskDao().findById(taskId)?.title
                        if (title != null) {
                            ReminderScheduler(appContext).schedule(
                                taskId,
                                title,
                                System.currentTimeMillis() +
                                    SNOOZE_MINUTES * 60_000L
                            )
                        }
                        Notifications.dismiss(appContext, taskId)
                    }

                    else -> {
                        // Re-read the task so a completed/edited task never fires a stale reminder.
                        val task = App2Database.get(appContext).taskDao().findById(taskId)
                        val title = task?.title ?: intent.getStringExtra(EXTRA_TITLE)
                        if (task != null && !task.isCompleted && task.reminderEnabled && title != null) {
                            Notifications.show(appContext, taskId, title)
                        }
                    }
                }
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val ACTION_REMIND = "com.javidstudio.app2.action.REMIND"
        const val ACTION_COMPLETE = "com.javidstudio.app2.action.COMPLETE"
        const val ACTION_SNOOZE = "com.javidstudio.app2.action.SNOOZE"

        /** How far ahead the snooze action re-arms a reminder. */
        const val SNOOZE_MINUTES = 5
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TITLE = "task_title"
    }
}
