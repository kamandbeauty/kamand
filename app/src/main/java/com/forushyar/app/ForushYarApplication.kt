package com.forushyar.app

import android.app.Application
import com.forushyar.app.core.AppLocales
import dagger.hilt.android.HiltAndroidApp
import java.util.Locale

@HiltAndroidApp
class ForushYarApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // زبان پیش‌فرض برنامه همیشه فارسی است
        Locale.setDefault(Locale(AppLocales.PERSIAN))
    }
}
