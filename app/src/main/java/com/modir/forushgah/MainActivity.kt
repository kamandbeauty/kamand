package com.modir.forushgah

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.modir.forushgah.core.designsystem.theme.ModirTheme
import com.modir.forushgah.presentation.navigation.ModirNavGraph
import com.modir.forushgah.presentation.onboarding.OnboardingRoute
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ModirTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    ModirApp()
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun ModirApp(rootViewModel: RootViewModel = hiltViewModel()) {
    val onboardingState by rootViewModel.onboardingCompleted.collectAsStateWithLifecycle()

    when (onboardingState) {
        null -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        false -> OnboardingRoute(onFinished = { rootViewModel.refresh() })
        true -> ModirNavGraph()
    }
}
