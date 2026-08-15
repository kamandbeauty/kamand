package com.roozi.app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.roozi.app.data.local.RooziDatabase
import com.roozi.app.data.repo.TaskRepository
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

                    else -> {
                        // Re-read the task so a completed/edited task never fires a stale reminder.
                        val task = RooziDatabase.get(appContext).taskDao().findById(taskId)
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
        const val ACTION_REMIND = "com.roozi.app.action.REMIND"
        const val ACTION_COMPLETE = "com.roozi.app.action.COMPLETE"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TITLE = "task_title"
    }
}
