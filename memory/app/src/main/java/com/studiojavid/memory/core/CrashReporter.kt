package com.studiojavid.memory.core

import android.content.Context
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Writes the last fatal exception to a local file so it can be shown inside the
 * app afterwards.
 *
 * Rationale: a release crash on a user's device is otherwise invisible — the
 * system dialog scrolls the useful top frames away and the rest is framework
 * noise. Everything stays on-device; nothing is uploaded.
 */
object CrashReporter {

    private const val FILE_NAME = "last_crash.txt"
    private const val TAG = "MemoryCrash"

    fun install(context: Context) {
        val appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            runCatching { write(appContext, thread, throwable) }
                .onFailure { Log.e(TAG, "Could not persist crash", it) }
            previous?.uncaughtException(thread, throwable)
        }
    }

    private fun write(context: Context, thread: Thread, throwable: Throwable) {
        val stack = StringWriter().also { writer ->
            PrintWriter(writer).use { throwable.printStackTrace(it) }
        }.toString()

        val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val report = buildString {
            appendLine("MEMORY crash report")
            appendLine("time: $stamp")
            appendLine("thread: ${thread.name}")
            appendLine("android: ${android.os.Build.VERSION.SDK_INT} (${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL})")
            appendLine()
            append(stack)
        }
        File(context.filesDir, FILE_NAME).writeText(report)
        Log.e(TAG, report)
    }

    /** The last recorded crash, or null when the app has never crashed. */
    fun lastCrash(context: Context): String? {
        val file = File(context.applicationContext.filesDir, FILE_NAME)
        if (!file.exists()) return null
        val text = runCatching { file.readText() }.getOrNull()
        return if (text.isNullOrBlank()) null else text
    }

    fun clear(context: Context) {
        runCatching { File(context.applicationContext.filesDir, FILE_NAME).delete() }
    }
}
