package com.roozi.app.core

import android.content.Context
import android.content.res.Configuration
import com.roozi.app.data.prefs.AppLanguage
import com.roozi.app.data.prefs.UserPreferences
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import java.util.Locale

/**
 * Applies the user's saved language to an Activity's base context.
 *
 * This belongs in attachBaseContext rather than in the composition: wrapping
 * LocalContext in a ConfigurationContext hides the Activity from APIs that walk
 * the context chain looking for one (activity results, permissions), which used
 * to crash the Today screen.
 *
 * Shared by every Activity so they cannot drift apart.
 */
object LocaleContext {

    fun language(context: Context): AppLanguage = runCatching {
        runBlocking { UserPreferences(context).settings.first().language }
    }.getOrDefault(AppLanguage.PERSIAN)

    /** Returns [base] re-configured for the user's language. */
    fun wrap(base: Context): Context {
        val locale = Locale(language(base).tag)
        Locale.setDefault(locale)
        val config = Configuration(base.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        return base.createConfigurationContext(config)
    }
}
