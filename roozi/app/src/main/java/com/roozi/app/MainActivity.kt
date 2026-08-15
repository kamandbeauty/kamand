package com.roozi.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
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
import com.roozi.app.core.CrashReporter
import com.roozi.app.data.backup.BackupManager
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.data.prefs.UserPreferences
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import com.roozi.app.ui.LocalDateFormatter
import com.roozi.app.ui.MainViewModel
import com.roozi.app.ui.components.CrashReportScreen
import com.roozi.app.ui.RooziAppScaffold
import com.roozi.app.ui.TasksViewModel
import com.roozi.app.ui.onboarding.OnboardingScreen
import com.roozi.app.ui.rememberDateFormatter
import com.roozi.app.ui.theme.RooziTheme
import java.util.Locale

class MainActivity : ComponentActivity() {

    private val mainViewModel: MainViewModel by viewModels { MainViewModel.Factory }
    private val tasksViewModel: TasksViewModel by viewModels { TasksViewModel.Factory }

    /** Set when launched from the Quick Add widget. */
    private var pendingQuickAdd by mutableStateOf(false)

    /** Language the Activity was created with; a change requires recreate(). */
    private var appliedLanguage: AppLanguage? = null

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* result handled by system */ }

    /**
     * Applies the user's language to the Activity itself.
     *
     * This is the correct place for it: wrapping LocalContext in the
     * composition would hide the Activity from APIs that need it (activity
     * results, permissions), while this keeps the whole context chain intact.
     */
    override fun attachBaseContext(newBase: Context) {
        val language = runCatching {
            runBlocking { UserPreferences(newBase).settings.first().language }
        }.getOrDefault(AppLanguage.PERSIAN)

        val locale = Locale(language.tag)
        Locale.setDefault(locale)
        val config = Configuration(newBase.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        var settingsReady = false
        splash.setKeepOnScreenCondition { !settingsReady }

        val app = application as RooziApp
        val backupManager = BackupManager(applicationContext, app.repository)
        pendingQuickAdd = intent?.getBooleanExtra(EXTRA_QUICK_ADD, false) == true

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

            RooziTheme(themeMode = current.theme, palette = current.palette) {
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
                            RooziAppScaffold(
                                tasksViewModel = tasksViewModel,
                                mainViewModel = mainViewModel,
                                backupManager = backupManager,
                                userName = current.name,
                                theme = current.theme,
                                language = current.language,
                                palette = current.palette,
                                onRequestNotificationPermission = ::requestNotificationPermissionIfNeeded,
                                openAddSheet = pendingQuickAdd,
                                onAddSheetOpened = { pendingQuickAdd = false }
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_QUICK_ADD, false)) pendingQuickAdd = true
    }

    override fun onResume() {
        super.onResume()
        tasksViewModel.refreshToday()
    }

    /**
     * Asked only when the user is about to create a task (i.e. when a reminder
     * becomes plausible), never on first launch.
     */
    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val settings = mainViewModel.settings.value ?: return
        if (settings.notificationPromptShown) return
        if (com.roozi.app.notifications.Notifications.hasPermission(this)) return
        mainViewModel.markNotificationPromptShown()
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    companion object {
        const val EXTRA_QUICK_ADD = "roozi.extra.quick_add"
    }
}
