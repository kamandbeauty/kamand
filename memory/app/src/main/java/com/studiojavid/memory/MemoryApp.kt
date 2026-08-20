package com.studiojavid.memory

import android.app.Application
import android.util.Log
import com.studiojavid.memory.core.CrashReporter
import com.studiojavid.memory.data.prefs.UserPreferences
import com.studiojavid.memory.data.repo.BirthdayRepository
import com.studiojavid.memory.data.repo.NoteRepository
import com.studiojavid.memory.data.repo.MemoryRepository
import com.studiojavid.memory.notifications.Notifications
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Tiny manual service locator — enough structure for an app this size,
 * without dragging in a DI framework.
 */
class MemoryApp : Application() {

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
    val memoryRepository: MemoryRepository by lazy { MemoryRepository(this) }
    val noteRepository: NoteRepository by lazy { NoteRepository(this) }
    val birthdayRepository: BirthdayRepository by lazy { BirthdayRepository(this) }

    override fun onCreate() {
        super.onCreate()
        // Installed first so it can capture failures from anything below.
        CrashReporter.install(this)

        runCatching { Notifications.ensureChannel(this) }
            .onFailure { Log.e(TAG, "Could not create the notification channel", it) }

        applicationScope.launch(Dispatchers.IO) {
            runCatching { noteRepository.ensureSeeded() }
                .onFailure { Log.e(TAG, "Seeding default notebooks failed", it) }
            runCatching { birthdayRepository.rescheduleAll() }
                .onFailure { Log.e(TAG, "Rescheduling birthday reminders failed", it) }
        }
    }

    private companion object {
        const val TAG = "MemoryApp"
    }
}
