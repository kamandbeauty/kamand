package com.roozi.app

import android.app.Application
import com.roozi.app.data.prefs.UserPreferences
import com.roozi.app.data.repo.TaskRepository
import com.roozi.app.notifications.Notifications
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Tiny manual service locator — enough structure for an app this size,
 * without dragging in a DI framework.
 */
class RooziApp : Application() {

    val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val preferences: UserPreferences by lazy { UserPreferences(this) }
    val repository: TaskRepository by lazy { TaskRepository(this) }

    override fun onCreate() {
        super.onCreate()
        Notifications.ensureChannel(this)
        applicationScope.launch(Dispatchers.IO) {
            repository.ensureSeeded()
            repository.rescheduleAllReminders()
        }
    }
}
