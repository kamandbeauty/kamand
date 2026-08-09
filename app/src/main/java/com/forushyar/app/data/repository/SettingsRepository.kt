package com.forushyar.app.data.repository

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class AppSettings(
    val shopName: String = "",
    val confirmDeletion: Boolean = true
)

/** تنظیمات سبک برنامه در حافظه داخلی و بدون وابستگی آنلاین ذخیره می‌شوند. */
@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext context: Context
) {
    private val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    private val _settings = MutableStateFlow(readSettings())
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    fun setShopName(value: String) {
        preferences.edit().putString(KEY_SHOP_NAME, value.trim()).apply()
        _settings.value = readSettings()
    }

    fun setConfirmDeletion(value: Boolean) {
        preferences.edit().putBoolean(KEY_CONFIRM_DELETION, value).apply()
        _settings.value = readSettings()
    }

    fun restore(settings: AppSettings) {
        preferences.edit()
            .putString(KEY_SHOP_NAME, settings.shopName.trim())
            .putBoolean(KEY_CONFIRM_DELETION, settings.confirmDeletion)
            .apply()
        _settings.value = readSettings()
    }

    private fun readSettings() = AppSettings(
        shopName = preferences.getString(KEY_SHOP_NAME, "").orEmpty(),
        confirmDeletion = preferences.getBoolean(KEY_CONFIRM_DELETION, true)
    )

    private companion object {
        const val PREFERENCES_NAME = "forushyar_settings"
        const val KEY_SHOP_NAME = "shop_name"
        const val KEY_CONFIRM_DELETION = "confirm_deletion"
    }
}
