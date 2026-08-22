package com.studiojavid.diary

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.util.Log
import com.studiojavid.diary.core.CrashReporter
import com.studiojavid.diary.data.prefs.UserPreferences
import com.studiojavid.diary.data.repo.BirthdayRepository
import com.studiojavid.diary.data.repo.DiaryRepository
import com.studiojavid.diary.data.repo.NoteRepository
import com.studiojavid.diary.notifications.Notifications
import com.studiojavid.diary.ui.lock.AppLock
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Tiny manual service locator — enough structure for an app this size,
 * without dragging in a DI framework.
 */
class DiaryApp : Application() {

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
    val diaryRepository: DiaryRepository by lazy { DiaryRepository(this) }
    val noteRepository: NoteRepository by lazy { NoteRepository(this) }
    val birthdayRepository: BirthdayRepository by lazy { BirthdayRepository(this) }
    val appLock: AppLock by lazy { AppLock() }

    /**
     * Counts currently started activities across the process. When the count
     * drops to 0 the whole app has moved to the background. The Activity that
     * drove the count to 0 is responsible for engaging the lock (it has direct
     * access to the latest settings snapshot via its ViewModel), so we only
     * expose the event here.
     */
    private val _inForeground = MutableStateFlow(false)
    val inForeground = _inForeground.asStateFlow()

    @Volatile
    var startedActivityCount: Int = 0
        private set

    fun onActivityStarted() {
        synchronized(this) { startedActivityCount += 1 }
    }

    fun onActivityStopped(changingConfigurations: Boolean): Boolean {
        if (changingConfigurations) return false
        var background = false
        synchronized(this) {
            startedActivityCount = (startedActivityCount - 1).coerceAtLeast(0)
            if (startedActivityCount == 0) background = true
        }
        if (background) _inForeground.value = false
        return background
    }

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
        const val TAG = "DiaryApp"
    }
}
