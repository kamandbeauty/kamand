package com.studiojavid.memory

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studiojavid.memory.core.CrashReporter
import com.studiojavid.memory.core.LocaleContext
import com.studiojavid.memory.notifications.Notifications
import com.studiojavid.memory.data.backup.BackupManager
import com.studiojavid.memory.data.prefs.AppLanguage
import com.studiojavid.memory.data.prefs.UserPreferences
import com.studiojavid.memory.ui.LocalDateFormatter
import com.studiojavid.memory.ui.MainViewModel
import com.studiojavid.memory.ui.components.CrashReportScreen
import com.studiojavid.memory.ui.MemoryAppScaffold
import com.studiojavid.memory.ui.MemoryViewModel
import com.studiojavid.memory.ui.onboarding.OnboardingScreen
import com.studiojavid.memory.ui.rememberDateFormatter
import com.studiojavid.memory.ui.theme.MemoryTheme

class MainActivity : ComponentActivity() {

    private val mainViewModel: MainViewModel by viewModels { MainViewModel.Factory }
    private val memoryViewModel: MemoryViewModel by viewModels { MemoryViewModel.Factory }

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

        var settingsReady = false
        splash.setKeepOnScreenCondition { !settingsReady }

        val app = application as MemoryApp
        val backupManager = BackupManager(
            applicationContext,
            app.memoryRepository,
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

            // LocalContext is the Activity, which attachBaseContext already
            // localized, so the formatter picks up the right resources.
            val formatter = rememberDateFormatter(persian)

            MemoryTheme(themeMode = current.theme, palette = current.palette) {
                // NOTE: LocalContext must keep pointing at the Activity.
                // Overriding it with a ConfigurationContext breaks anything that
                // walks the context chain looking for an Activity — notably
                // rememberLauncherForActivityResult, which threw
                // "No ActivityResultRegistryOwner was provided" and crashed the
                // Today screen. The locale is applied to the Activity itself in
                // attachBaseContext instead.
                CompositionLocalProvider(
                    LocalLayoutDirection provides if (persian) LayoutDirection.Rtl else LayoutDirection.Ltr,
                    LocalDateFormatter provides formatter
                ) {
                    // If the previous launch crashed, surface the report first
                    // instead of dropping the user into a screen that may crash
                    // again with no explanation.
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
                            MemoryAppScaffold(
                                memoryViewModel = memoryViewModel,
                                mainViewModel = mainViewModel,
                                backupManager = backupManager,
                                userName = current.name,
                                theme = current.theme,
                                language = current.language,
                                palette = current.palette,
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
        memoryViewModel.refreshToday()
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
