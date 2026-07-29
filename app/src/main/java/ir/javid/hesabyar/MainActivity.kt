package ir.javid.hesabyar

import android.content.Intent
import android.os.Bundle
import android.os.Process
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.LocalLayoutDirection
import dagger.hilt.android.AndroidEntryPoint
import ir.javid.hesabyar.core.ui.HesabyarTheme
import ir.javid.hesabyar.navigation.HesabyarApp

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContent {
            HesabyarTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    HesabyarApp(onRestoreCompleted = ::restartAfterRestore)
                }
            }
        }
    }

    /** Room is deliberately closed during restore; restart to rebuild the Hilt graph against the new file. */
    private fun restartAfterRestore() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        if (launchIntent == null) {
            recreate()
            return
        }
        startActivity(launchIntent)
        finishAffinity()
        Process.killProcess(Process.myPid())
    }
}
