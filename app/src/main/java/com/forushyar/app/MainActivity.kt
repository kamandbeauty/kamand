package com.forushyar.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.forushyar.app.core.AppLocales
import com.forushyar.app.core.LocaleManager
import com.forushyar.app.ui.navigation.AppNavGraph
import com.forushyar.app.ui.theme.ForushYarTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleManager.updateResources(newBase, AppLocales.PERSIAN))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ForushYarTheme {
                AppNavGraph()
            }
        }
    }
}
