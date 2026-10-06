package com.ruby.factor_ruby

import android.app.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * طالع من — entry activity.
 *
 * Hosts the `app/notifications` MethodChannel used by the Dart side for the
 * daily horoscope reminder. The native implementation lives in
 * [NotificationScheduler] (channel methods, AlarmManager wiring, boot
 * receiver) — no third-party notification dependency is bundled.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native share sheet (keeps the app dependency-free).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/share",
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                val text = call.argument<String>("text") ?: ""
                val subject = call.argument<String>("subject") ?: "طالع من"
                try {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                    }
                    startActivity(Intent.createChooser(intent, "اشتراک‌گذاری"))
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.error("no_share_app", "No app available to share", null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NotificationScheduler.CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationScheduler.ensureChannel(applicationContext)
                    result.success(true)
                }
                "requestPermission" ->
                    NotificationScheduler.requestPermission(this, result)
                "scheduleDaily" -> {
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 0
                    NotificationScheduler.ensureChannel(applicationContext)
                    NotificationScheduler.scheduleDaily(applicationContext, hour, minute)
                    result.success(true)
                }
                "cancel" -> {
                    NotificationScheduler.cancel(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        NotificationScheduler.onPermissionResult(requestCode, grantResults)
    }
}

/** Reschedules the daily reminder after a device reboot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            NotificationScheduler.rescheduleFromPrefs(context)
        }
    }
}

/** Fires the notification when the alarm triggers. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NotificationScheduler.showDailyNotification(context)
    }
}
