package com.studiojavid.diary

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.fragment.app.FragmentActivity
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.diary.core.CrashReporter
import com.studiojavid.diary.core.LocaleContext
import com.studiojavid.diary.notifications.Notifications
import com.studiojavid.diary.data.backup.BackupManager
import com.studiojavid.diary.data.prefs.AppLanguage
import com.studiojavid.diary.ui.LocalDateFormatter
import com.studiojavid.diary.ui.MainViewModel
import com.studiojavid.diary.ui.components.CrashReportScreen
import com.studiojavid.diary.ui.DiaryAppScaffold
import com.studiojavid.diary.ui.DiaryViewModel
import com.studiojavid.diary.ui.lock.LockScreen
import com.studiojavid.diary.ui.onboarding.OnboardingScreen
import com.studiojavid.diary.ui.rememberDateFormatter
import com.studiojavid.diary.ui.theme.DiaryTheme

class MainActivity : FragmentActivity() {

    private val mainViewModel: MainViewModel by viewModels { MainViewModel.Factory }
    private val diaryViewModel: DiaryViewModel by viewModels { DiaryViewModel.Factory }

    /** Language the Activity was created with; a change requires recreate(). */
    private var appliedLanguage: AppLanguage? = null

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* result handled by system */ }

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleContext.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val app = application as DiaryApp
        val lock = app.appLock

        var settingsReady = false
        splash.setKeepOnScreenCondition { !settingsReady }

        val backupManager = BackupManager(
            applicationContext,
            app.diaryRepository,
            app.noteRepository,
            app.birthdayRepository
        )

        setContent {
            val settings by mainViewModel.settings.collectAsStateWithLifecycle()
            LaunchedEffect(settings) { if (settings != null) settingsReady = true }

            val current = settings ?: return@setContent
            val persian = current.language.isPersian

            // The Activity locale is applied in attachBaseContext, so a language
            // change only takes effect after recreation.
            LaunchedEffect(current.language) {
                if (appliedLanguage == null) {
                    appliedLanguage = current.language
                } else if (appliedLanguage != current.language) {
                    appliedLanguage = current.language
                    recreate()
                }
            }

            val formatter = rememberDateFormatter(persian)

            // Drive the lock state from the user's setting. On cold start
            // (initial load), if lock is enabled we start locked; if the user
            // flips the toggle OFF we unlock; if they flip it ON mid-session
            // we lock immediately.
            LaunchedEffect(current.lockMode) {
                if (current.lockMode.enabled) lock.lock() else lock.unlock()
            }

            val isUnlocked by lock.isUnlocked.collectAsStateWithLifecycle()

            DiaryTheme(themeMode = current.theme, palette = current.palette) {
                CompositionLocalProvider(
                    LocalLayoutDirection provides if (persian) LayoutDirection.Rtl else LayoutDirection.Ltr,
                    LocalDateFormatter provides formatter
                ) {
                    var crash by remember { mutableStateOf(CrashReporter.lastCrash(applicationContext)) }
                    val pendingCrash = crash
                    if (pendingCrash != null) {
                        CrashReportScreen(
                            report = pendingCrash,
                            onDismiss = {
                                CrashReporter.clear(applicationContext)
                                crash = null
                            }
                        )
                        return@CompositionLocalProvider
                    }

                    // Lock gate sits on top of everything else (including the
                    // onboarding flow). Once unlocked the normal content shows.
                    if (current.lockMode.enabled && !isUnlocked) {
                        LockScreen(appLock = lock)
                        return@CompositionLocalProvider
                    }

                    Crossfade(
                        targetState = current.onboardingDone,
                        animationSpec = tween(320),
                        label = "rootCrossfade"
                    ) { onboarded ->
                        if (!onboarded) {
                            OnboardingScreen(
                                onFinish = { name ->
                                    if (name.isNotBlank()) mainViewModel.setName(name)
                                    mainViewModel.completeOnboarding()
                                }
                            )
                        } else {
                            DiaryAppScaffold(
                                diaryViewModel = diaryViewModel,
                                mainViewModel = mainViewModel,
                                backupManager = backupManager,
                                userName = current.name,
                                theme = current.theme,
                                language = current.language,
                                palette = current.palette,
                                lockMode = current.lockMode,
                                lockImmediate = current.lockImmediate,
                                onRequestNotificationPermission = ::ensureNotificationPermission
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // A diary left open overnight must roll onto the new day rather than
        // keep offering to write yesterday's page.
        diaryViewModel.refreshToday()
    }

    /**
     * Asked when the user actually switches a reminder on.
     *
     * Unlike the soft prompt above this ignores notificationPromptShown: if
     * reminders are being enabled, the permission is genuinely required, and
     * silently doing nothing would leave the user with a reminder that can
     * never fire. When the system will no longer show the dialog we send the
     * user to the app's notification settings instead.
     */
    fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (Notifications.hasPermission(this)) return

        if (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) ||
            !mainViewModel.settings.value?.notificationPromptShown.orFalse()
        ) {
            mainViewModel.markNotificationPromptShown()
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            openNotificationSettings()
        }
    }

    /** Opens this app's notification settings so a denied permission is fixable. */
    fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        runCatching { startActivity(intent) }.onFailure { openAppDetailsSettings() }
    }

    /** Last-resort settings target; every OEM has this page. */
    private fun openAppDetailsSettings() {
        runCatching {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    android.net.Uri.fromParts("package", packageName, null)
                )
            )
        }
    }

    private fun Boolean?.orFalse(): Boolean = this ?: false
}
