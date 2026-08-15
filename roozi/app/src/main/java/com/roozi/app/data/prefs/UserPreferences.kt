package com.roozi.app.data.prefs

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import com.roozi.app.ui.theme.ThemePalette
import kotlinx.coroutines.flow.map

enum class ThemeMode { SYSTEM, LIGHT, DARK }

enum class AppLanguage(val tag: String) {
    PERSIAN("fa"), ENGLISH("en");

    val isPersian: Boolean get() = this == PERSIAN

    companion object {
        fun fromTag(tag: String?): AppLanguage = if (tag == ENGLISH.tag) ENGLISH else PERSIAN
    }
}

data class UserSettings(
    val name: String = "",
    val onboardingDone: Boolean = false,
    val theme: ThemeMode = ThemeMode.SYSTEM,
    val language: AppLanguage = AppLanguage.PERSIAN,
    val notificationPromptShown: Boolean = false,
    val fullScreenPromptShown: Boolean = false,
    val palette: ThemePalette = ThemePalette.RAINBOW
)

private val Context.dataStore by preferencesDataStore(name = "roozi_settings")

class UserPreferences(private val context: Context) {

    private object Keys {
        val NAME = stringPreferencesKey("user_name")
        val ONBOARDING = booleanPreferencesKey("onboarding_done")
        val THEME = stringPreferencesKey("theme_mode")
        val LANGUAGE = stringPreferencesKey("language")
        val NOTIF_PROMPT = booleanPreferencesKey("notification_prompt_shown")
        val FULLSCREEN_PROMPT = booleanPreferencesKey("fullscreen_prompt_shown")
        val PALETTE = stringPreferencesKey("theme_palette")
    }

    val settings: Flow<UserSettings> = context.dataStore.data.map { it.toSettings() }

    private fun Preferences.toSettings() = UserSettings(
        name = this[Keys.NAME].orEmpty(),
        onboardingDone = this[Keys.ONBOARDING] ?: false,
        theme = runCatching { ThemeMode.valueOf(this[Keys.THEME] ?: ThemeMode.SYSTEM.name) }
            .getOrDefault(ThemeMode.SYSTEM),
        language = AppLanguage.fromTag(this[Keys.LANGUAGE]),
        notificationPromptShown = this[Keys.NOTIF_PROMPT] ?: false,
        fullScreenPromptShown = this[Keys.FULLSCREEN_PROMPT] ?: false,
        palette = ThemePalette.fromId(this[Keys.PALETTE])
    )

    suspend fun setName(name: String) = context.dataStore.edit { it[Keys.NAME] = name.trim() }

    suspend fun setOnboardingDone(done: Boolean) = context.dataStore.edit { it[Keys.ONBOARDING] = done }

    suspend fun setTheme(mode: ThemeMode) = context.dataStore.edit { it[Keys.THEME] = mode.name }

    suspend fun setLanguage(language: AppLanguage) =
        context.dataStore.edit { it[Keys.LANGUAGE] = language.tag }

    suspend fun setNotificationPromptShown(shown: Boolean) =
        context.dataStore.edit { it[Keys.NOTIF_PROMPT] = shown }

    suspend fun setFullScreenPromptShown(shown: Boolean) =
        context.dataStore.edit { it[Keys.FULLSCREEN_PROMPT] = shown }

    suspend fun setPalette(palette: ThemePalette) =
        context.dataStore.edit { it[Keys.PALETTE] = palette.id }
}
