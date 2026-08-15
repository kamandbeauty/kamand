package com.roozi.app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.lifecycleScope
import com.roozi.app.core.LocaleContext
import com.roozi.app.core.util.PersianNumbers
import com.roozi.app.data.prefs.UserPreferences
import com.roozi.app.notifications.Notifications
import com.roozi.app.notifications.ReminderScheduler
import com.roozi.app.ui.alarm.AlarmScreen
import com.roozi.app.ui.theme.RooziTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

/**
 * Alarm-clock style reminder screen, launched by a full-screen intent.
 *
 * Shows over the lock screen and turns the display on, the same way an incoming
 * call does, so a reminder the user deliberately set is not lost in the shade.
 * When the OS withholds the full-screen-intent capability the notification is
 * still posted and simply stays a heads-up banner — see [Notifications.show].
 */
class AlarmActivity : ComponentActivity() {

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleContext.wrap(newBase))
    }

    /**
     * Current reminder. Held as state because the activity is singleInstance:
     * a second reminder arriving while this one is up is delivered to the same
     * instance, and without this the screen would keep showing the first title.
     */
    private var current by mutableStateOf<Reminder?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        enableEdgeToEdge()

        val first = reminderFrom(intent)
        if (first == null) {
            finish()
            return
        }
        current = first

        // The notification is deliberately left in the shade while this screen
        // is up. Dismissing it here would destroy the reminder outright if the
        // user pressed home instead of choosing an action; it is cancelled when
        // snooze or acknowledge is actually pressed.
        val settings = runCatching {
            runBlocking { UserPreferences(this@AlarmActivity).settings.first() }
        }.getOrNull()
        val persian = settings?.language?.isPersian ?: true

        setContent {
            RooziTheme(
                themeMode = settings?.theme ?: com.roozi.app.data.prefs.ThemeMode.SYSTEM,
                palette = settings?.palette ?: com.roozi.app.ui.theme.ThemePalette.RAINBOW
            ) {
                CompositionLocalProvider(
                    LocalLayoutDirection provides
                        if (persian) LayoutDirection.Rtl else LayoutDirection.Ltr
                ) {
                    val reminder = current ?: return@CompositionLocalProvider
                    AlarmScreen(
                        title = reminder.title,
                        time = clockNow(persian),
                        snoozeLabel = getString(
                            R.string.alarm_snooze_for,
                            PersianNumbers.format(SNOOZE_MINUTES, persian)
                        ),
                        onSnooze = { snooze(reminder.id, reminder.title) },
                        onGotIt = { dismiss(reminder.id) }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reminderFrom(intent)?.let { current = it }
    }

    private fun reminderFrom(intent: Intent?): Reminder? {
        val id = intent?.getLongExtra(EXTRA_TASK_ID, -1L) ?: -1L
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        return if (id > 0 && title.isNotBlank()) Reminder(id, title) else null
    }

    private data class Reminder(val id: Long, val title: String)

    /** Re-arms the same reminder a few minutes out. */
    private fun snooze(taskId: Long, title: String) {
        // The preview is a mock-up of a reminder, not one: re-arming it would
        // make a notification appear later for a task that does not exist.
        if (taskId == PREVIEW_TASK_ID) {
            dismiss(taskId)
            return
        }
        val at = System.currentTimeMillis() + SNOOZE_MINUTES * 60_000L
        lifecycleScope.launch {
            withContext(Dispatchers.IO) {
                runCatching { ReminderScheduler(applicationContext).schedule(taskId, title, at) }
            }
            dismiss(taskId)
        }
    }

    /** Clears the paired notification and closes; the reminder is resolved. */
    private fun dismiss(taskId: Long) {
        Notifications.dismiss(applicationContext, taskId)
        finishAndRemoveTask()
    }

    private fun clockNow(persian: Boolean): String {
        val now = java.time.LocalTime.now()
        return PersianNumbers.twoDigits(now.hour, persian) + ":" +
            PersianNumbers.twoDigits(now.minute, persian)
    }

    /**
     * Makes the screen behave like an alarm: wakes the display and draws over
     * the keyguard. The setShowWhenLocked/setTurnScreenOn pair is the modern
     * API; the window flags cover API < 27.
     */
    @Suppress("DEPRECATION")
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        const val EXTRA_TASK_ID = "roozi.extra.alarm_task_id"
        const val EXTRA_TITLE = "roozi.extra.alarm_title"

        /** Matches the shortest interval the wheel picker offers. */
        const val SNOOZE_MINUTES = 5

        /**
         * Id used by the Profile preview. It matches no real row, so snoozing
         * the preview cannot schedule an alarm for a task that does not exist.
         */
        const val PREVIEW_TASK_ID = 999_998L

        /** Named createIntent so it cannot shadow Activity.intent inside this class. */
        fun createIntent(context: Context, taskId: Long, title: String): Intent =
            Intent(context, AlarmActivity::class.java).apply {
                // The activity has its own taskAffinity, so NEW_TASK is enough
                // to give it a separate task. CLEAR_TASK is deliberately absent:
                // it would tear down whatever the user had open in the app.
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
            }
    }
}
