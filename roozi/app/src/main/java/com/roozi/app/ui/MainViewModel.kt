package com.roozi.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.roozi.app.RooziApp
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.data.prefs.ThemeMode
import com.roozi.app.data.prefs.UserPreferences
import com.roozi.app.data.prefs.UserSettings
import com.roozi.app.ui.theme.ThemePalette
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Owns app-wide settings: name, language, theme and onboarding state. */
class MainViewModel(private val prefs: UserPreferences) : ViewModel() {

    val settings: StateFlow<UserSettings?> = prefs.settings
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    fun setName(name: String) = viewModelScope.launch { prefs.setName(name) }

    fun completeOnboarding() = viewModelScope.launch { prefs.setOnboardingDone(true) }

    fun setTheme(mode: ThemeMode) = viewModelScope.launch { prefs.setTheme(mode) }

    fun setLanguage(language: AppLanguage) = viewModelScope.launch { prefs.setLanguage(language) }

    fun setPalette(palette: ThemePalette) = viewModelScope.launch { prefs.setPalette(palette) }

    fun markNotificationPromptShown() = viewModelScope.launch { prefs.setNotificationPromptShown(true) }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer { MainViewModel(app().preferences) }
        }
    }
}

internal fun CreationExtras.app(): RooziApp =
    this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as RooziApp
