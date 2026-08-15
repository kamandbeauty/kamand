package com.roozi.app

import android.app.Application
import android.util.Log
import com.roozi.app.core.CrashReporter
import com.roozi.app.data.prefs.UserPreferences
import com.roozi.app.data.repo.BirthdayRepository
import com.roozi.app.data.repo.NoteRepository
import com.roozi.app.data.repo.TaskRepository
import com.roozi.app.notifications.Notifications
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Tiny manual service locator — enough structure for an app this size,
 * without dragging in a DI framework.
 */
class RooziApp : Application() {

    /**
     * Startup work must never be able to take the process down: an uncaught
     * exception in this scope (a corrupt database, a denied alarm, …) would
     * otherwise crash the app on every single launch, leaving the user with no
     * way back in. Failures are logged and the app continues.
     */
    private val startupErrorHandler = CoroutineExceptionHandler { _, throwable ->
        Log.e(TAG, "Startup task failed", throwable)
    }

    val applicationScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Default + startupErrorHandler)

    val preferences: UserPreferences by lazy { UserPreferences(this) }
    val repository: TaskRepository by lazy { TaskRepository(this) }
    val noteRepository: NoteRepository by lazy { NoteRepository(this) }
    val birthdayRepository: BirthdayRepository by lazy { BirthdayRepository(this) }

    override fun onCreate() {
        super.onCreate()
        // Installed first so it can capture failures from anything below.
        CrashReporter.install(this)

        runCatching { Notifications.ensureChannel(this) }
            .onFailure { Log.e(TAG, "Could not create the notification channel", it) }

        applicationScope.launch(Dispatchers.IO) {
            runCatching { repository.ensureSeeded() }
                .onFailure { Log.e(TAG, "Seeding default categories failed", it) }
            runCatching { noteRepository.ensureSeeded() }
                .onFailure { Log.e(TAG, "Seeding default notebooks failed", it) }
            runCatching { repository.rescheduleAllReminders() }
                .onFailure { Log.e(TAG, "Rescheduling reminders failed", it) }
            runCatching { birthdayRepository.rescheduleAll() }
                .onFailure { Log.e(TAG, "Rescheduling birthday reminders failed", it) }
        }
    }

    private companion object {
        const val TAG = "RooziApp"
    }
}
