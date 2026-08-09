package ir.factoryar.core.datastore

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "factoryar_settings")

/** دسترسی سطح پایین به DataStore تنظیمات (پیاده‌سازی SettingsRepository در core:data) */
class SettingsDataStore(private val context: Context) {

    object Keys {
        val THEME_MODE = stringPreferencesKey("theme_mode")
        val THEME_PRESET = stringPreferencesKey("theme_preset")
        val CUSTOM_PRIMARY = longPreferencesKey("custom_primary_argb")
        val CURRENCY_UNIT = stringPreferencesKey("currency_unit")
        val DEFAULT_TAX = doublePreferencesKey("default_tax_percent")
        val DEFAULT_TERMS = stringPreferencesKey("default_terms")
        val PRINT_SHOW_LOGO = booleanPreferencesKey("print_show_logo")
        val PRINT_SHOW_SIGNATURE = booleanPreferencesKey("print_show_signature")
        val PRINT_SHOW_TERMS = booleanPreferencesKey("print_show_terms")
        val WEEKLY_BACKUP = booleanPreferencesKey("weekly_backup")
        val IS_PREMIUM = booleanPreferencesKey("is_premium")
        val DB_PASSPHRASE = stringPreferencesKey("db_passphrase")

        fun prefixKey(type: String) = stringPreferencesKey("invoice_prefix_$type")
        fun nextNumberKey(type: String) = longPreferencesKey("invoice_next_$type")
    }

    val raw: Flow<androidx.datastore.preferences.core.Preferences> = context.dataStore.data

    fun <T> get(key: androidx.datastore.preferences.core.Preferences.Key<T>, default: T): Flow<T> =
        raw.map { it[key] ?: default }

    suspend fun <T> set(key: androidx.datastore.preferences.core.Preferences.Key<T>, value: T) {
        context.dataStore.edit { it[key] = value }
    }

    suspend fun <T> remove(key: androidx.datastore.preferences.core.Preferences.Key<T>) {
        context.dataStore.edit { it.remove(key) }
    }

    suspend fun edit(transform: (androidx.datastore.preferences.core.MutablePreferences) -> Unit) {
        context.dataStore.edit(transform)
    }

    suspend fun snapshot(): androidx.datastore.preferences.core.Preferences = raw.first()
}
