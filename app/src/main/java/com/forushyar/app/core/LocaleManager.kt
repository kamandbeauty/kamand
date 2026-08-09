package com.forushyar.app.core

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

object AppLocales {
    const val PERSIAN = "fa"
}

/**
 * اطمینان از اینکه برنامه همیشه فارسی و راست‌به‌چپ (RTL) نمایش داده می‌شود،
 * حتی اگر زبان سیستم دستگاه فارسی نباشد.
 */
object LocaleManager {

    fun updateResources(context: Context, language: String): Context {
        val locale = Locale(language)
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        config.setLayoutDirection(locale)
        return context.createConfigurationContext(config)
    }
}
