package ir.factoryar.app

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dagger.hilt.android.AndroidEntryPoint
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.ui.theme.FactorYarTheme

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    /** مقصد ناوبری آمده از نوتیفیکیشن یا ویجت صفحه اصلی */
    private var pendingRoute by mutableStateOf<String?>(null)

    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* اختیاری */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        pendingRoute = intent?.getStringExtra(EXTRA_NAVIGATE)
        askNotificationPermissionOnce()

        setContent {
            val viewModel: MainViewModel = hiltViewModel()
            val settings by viewModel.settings.collectAsStateWithLifecycle()

            FactorYarTheme(
                themeMode = settings.themeMode,
                themePreset = settings.themePreset,
                customPrimaryArgb = settings.customPrimaryColor,
                currencyUnit = CurrencyUnit.fromName(settings.currencyUnit),
                isPremium = settings.isPremium,
            ) {
                MainScaffold(initialRoute = pendingRoute)
            }
        }
    }

    private fun askNotificationPermissionOnce() {
        if (Build.VERSION.SDK_INT >= 33) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    /** ورود از ویجت/نوتیفیکیشن وقتی اپ از قبل باز است */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingRoute = intent.getStringExtra(EXTRA_NAVIGATE)
    }

    companion object {
        const val EXTRA_NAVIGATE = "navigate_to"
    }
}
