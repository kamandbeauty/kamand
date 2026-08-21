package com.studiojavid.diary.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.studiojavid.diary.DiaryApp
import com.studiojavid.diary.data.prefs.AppLanguage
import com.studiojavid.diary.data.prefs.ThemeMode
import com.studiojavid.diary.data.prefs.UserPreferences
import com.studiojavid.diary.data.prefs.UserSettings
import com.studiojavid.diary.ui.lock.LockMode
import com.studiojavid.diary.ui.theme.ThemePalette
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Owns app-wide settings: name, language, theme, lock and onboarding state. */
class MainViewModel(private val prefs: UserPreferences) : ViewModel() {

    val settings: StateFlow<UserSettings?> = prefs.settings
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    fun setName(name: String) = viewModelScope.launch { prefs.setName(name) }

    fun completeOnboarding() = viewModelScope.launch { prefs.setOnboardingDone(true) }

    fun setTheme(mode: ThemeMode) = viewModelScope.launch { prefs.setTheme(mode) }

    fun setLanguage(language: AppLanguage) = viewModelScope.launch { prefs.setLanguage(language) }

    fun setPalette(palette: ThemePalette) = viewModelScope.launch { prefs.setPalette(palette) }

    fun markNotificationPromptShown() = viewModelScope.launch { prefs.setNotificationPromptShown(true) }

    fun setLockMode(mode: LockMode) = viewModelScope.launch { prefs.setLockMode(mode) }

    fun setLockImmediate(immediate: Boolean) = viewModelScope.launch { prefs.setLockImmediate(immediate) }


    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer { MainViewModel(app().preferences) }
        }
    }
}

internal fun CreationExtras.app(): DiaryApp =
    this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as DiaryApp
