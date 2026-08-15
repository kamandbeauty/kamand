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
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.roozi.app.data.backup.BackupManager
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.ui.LocalDateFormatter
import com.roozi.app.ui.MainViewModel
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

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* result handled by system */ }

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

            // Apply the chosen language & direction to the whole composition.
            val localizedContext = rememberLocalizedContext(current.language)
            val formatter = rememberDateFormatter(persian)

            RooziTheme(themeMode = current.theme, palette = current.palette) {
                CompositionLocalProvider(
                    LocalContext provides localizedContext,
                    LocalLayoutDirection provides if (persian) LayoutDirection.Rtl else LayoutDirection.Ltr,
                    LocalDateFormatter provides DateFormatterFor(localizedContext, persian)
                ) {
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

@androidx.compose.runtime.Composable
private fun rememberLocalizedContext(language: AppLanguage): Context {
    val base = LocalContext.current
    val configuration = LocalConfiguration.current
    return remember(base, language, configuration) {
        val locale = Locale(language.tag)
        Locale.setDefault(locale)
        val config = Configuration(configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        base.createConfigurationContext(config)
    }
}

@androidx.compose.runtime.Composable
private fun DateFormatterFor(context: Context, persian: Boolean) =
    remember(context, persian) { com.roozi.app.core.date.DateFormatter(context, persian) }
