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
     * Whether the app is currently in the foreground (any activity started).
     * Driven by ActivityLifecycleCallbacks so it survives configuration changes
     * and correctly ignores transient activity switches (system dialogs,
     * opening Settings, etc.).
     */
    private val _inForeground = MutableStateFlow(false)
    val inForeground = _inForeground.asStateFlow()

    override fun onCreate() {
        super.onCreate()
        // Installed first so it can capture failures from anything below.
        CrashReporter.install(this)

        registerActivityLifecycleCallbacks(LifecycleTracker())

        runCatching { Notifications.ensureChannel(this) }
            .onFailure { Log.e(TAG, "Could not create the notification channel", it) }

        applicationScope.launch(Dispatchers.IO) {
            runCatching { noteRepository.ensureSeeded() }
                .onFailure { Log.e(TAG, "Seeding default notebooks failed", it) }
            runCatching { birthdayRepository.rescheduleAll() }
                .onFailure { Log.e(TAG, "Rescheduling birthday reminders failed", it) }
        }
    }

    /**
     * Counts started activities to know when the app leaves the foreground.
     * When the counter hits 0 we engage the lock if the user opted into
     * immediate relock. Configuration changes are explicitly skipped.
     */
    private inner class LifecycleTracker : ActivityLifecycleCallbacks {
        private var started = 0

        override fun onActivityStarted(activity: Activity) {
            val first = synchronized(this) {
                started += 1
                started == 1
            }
            if (first) _inForeground.value = true
        }

        override fun onActivityStopped(activity: Activity) {
            if (activity.isChangingConfigurations) return
            val last = synchronized(this) {
                started = (started - 1).coerceAtLeast(0)
                started == 0
            }
            if (last) {
                _inForeground.value = false
                applicationScope.launch {
                    val immediate = runCatching { preferences.settings }
                        .getOrNull()
                        ?.let { it.lockImmediate && it.lockMode.enabled }
                        ?: true
                    if (immediate) appLock.lock()
                }
            }
        }

        override fun onActivityCreated(a: Activity, b: Bundle?) {}
        override fun onActivityResumed(a: Activity) {}
        override fun onActivityPaused(a: Activity) {}
        override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
        override fun onActivityDestroyed(a: Activity) {}
    }

    private companion object {
        const val TAG = "DiaryApp"
    }
}
