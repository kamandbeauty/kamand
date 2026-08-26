package com.modir.forushgah

import android.app.Application
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.modir.forushgah.BuildConfig
import com.modir.forushgah.data.repository.ExpenseRepository
import com.modir.forushgah.data.sample.ReferenceDataSeeder
import com.modir.forushgah.data.sample.SampleDataSeeder
import dagger.hilt.android.HiltAndroidApp
import java.io.File
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@HiltAndroidApp
class ModirApplication : Application() {

    @Inject
    lateinit var sampleDataSeeder: SampleDataSeeder

    @Inject
    lateinit var referenceDataSeeder: ReferenceDataSeeder

    @Inject
    lateinit var expenseRepository: ExpenseRepository

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        installCrashLoggerIfDebug()
        // Robolectric unit tests instantiate this Application without Hilt,
        // so the @Inject seeders are not initialized there — guard for it.
        if (!::referenceDataSeeder.isInitialized ||
            !::sampleDataSeeder.isInitialized ||
            !::expenseRepository.isInitialized
        ) {
            return
        }
        // Built-in reference data (channels/providers/payment methods) — real
        // configuration, idempotent, all builds.
        applicationScope.launch { referenceDataSeeder.seedBuiltIns() }
        // Built-in expense categories (Phase 4.2) — real configuration,
        // seeded exactly once (idempotent), all builds.
        applicationScope.launch { expenseRepository.seedBuiltInCategories() }
        // Debug-only sample data (spec §17): never runs in release builds and
        // never re-seeds a database that already has products.
        applicationScope.launch { sampleDataSeeder.seedIfEmpty() }
    }

    /**
     * Debug builds only: capture uncaught exceptions to a readable log file
     * so a device crash can be diagnosed without a computer/adb.
     *
     * - API 29+: written to the public Downloads folder (no permission needed).
     * - older: written to the app-external files dir (also no permission needed).
     *
     * File name: `modir-crash-<timestamp>.log` with the full stack-trace chain.
     * The previous (system) handler is always invoked afterwards, so normal
     * crash behavior is unchanged.
     */
    private fun installCrashLoggerIfDebug() {
        if (!BuildConfig.DEBUG) return
        val original = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                writeCrashLog(thread, throwable)
            } catch (_: Exception) {
                // the logger must never break the crash path
            } finally {
                original?.uncaughtException(thread, throwable)
            }
        }
    }

    @Suppress("NewApi") // MediaStore.Downloads is guarded by the SDK check below
    private fun writeCrashLog(thread: Thread, throwable: Throwable) {
        val timestamp = System.currentTimeMillis()
        val text = buildString {
            appendLine("app: $packageName v${BuildConfig.VERSION_NAME}")
            appendLine("device: ${Build.MODEL} / Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            appendLine("time: $timestamp")
            appendLine("thread: ${thread.name}")
            appendLine()
            append(throwable.stackTraceToString())
            var cause = throwable.cause
            while (cause != null && cause !== throwable) {
                appendLine()
                appendLine("--- caused by ---")
                append(cause.stackTraceToString())
                cause = cause.cause
            }
        }
        val fallback = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "modir-crash-$timestamp.log")
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, "modir-crash-$timestamp.log")
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
            } else {
                fallback.writeText(text)
            }
        } else {
            fallback.writeText(text)
        }
    }
}
