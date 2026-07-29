package ir.factoryar.app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import ir.factoryar.app.R

object NotificationHelper {

    const val CHANNEL_RECURRING = "recurring_invoices"
    const val CHANNEL_BACKUP = "auto_backup"
    const val CHANNEL_DEBT = "debt_reminders"
    const val CHANNEL_STOCK = "stock_alerts"

    fun createChannels(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_RECURRING, "یادآور فاکتورهای دوره‌ای", NotificationManager.IMPORTANCE_DEFAULT),
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_BACKUP, "پشتیبان‌گیری خودکار", NotificationManager.IMPORTANCE_LOW),
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_DEBT, "یادآوری بدهی مشتریان", NotificationManager.IMPORTANCE_DEFAULT),
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_STOCK, "هشدار کمبود موجودی", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    private fun permissionGranted(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

    private fun openAppIntent(context: Context, target: String): PendingIntent {
        val intent = (
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent().setPackage(context.packageName)
            ).apply {
                putExtra("navigate_to", target)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        return PendingIntent.getActivity(
            context, target.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** فاکتور دوره‌ای ساخته شد */
    fun notifyRecurringInvoices(context: Context, count: Int) {
        if (!permissionGranted(context)) return
        val n = NotificationCompat.Builder(context, CHANNEL_RECURRING)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("صدور خودکار فاکتور دوره‌ای")
            .setContentText("$count فاکتور دوره‌ای به‌صورت خودکار صادر شد")
            .setContentIntent(openAppIntent(context, "invoices"))
            .setAutoCancel(true)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(1001, n)
    }

    /** یادآوری بدهی معوق (پیگیری مشتری) */
    fun notifyOverdueDebts(
        context: Context,
        customerCount: Int,
        totalLabel: String,
        topDebtorName: String = "",
        maxOverdueDays: Int = 0,
    ) {
        if (!permissionGranted(context) || customerCount == 0) return
        val summary = "$customerCount مشتری بدهکار — مجموع $totalLabel"
        val detail = buildString {
            append(summary)
            if (topDebtorName.isNotBlank()) {
                append("\n")
                append("بیشترین تأخیر: ")
                append(topDebtorName)
                if (maxOverdueDays > 0) {
                    append(" ($maxOverdueDays روز)")
                }
            }
            append("\nبرای مشاهده فهرست و ارسال یادآوری، ضربه بزنید.")
        }
        val n = NotificationCompat.Builder(context, CHANNEL_DEBT)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("پیگیری بدهی‌های معوق")
            .setContentText(summary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(detail))
            .setContentIntent(openAppIntent(context, "debtors"))
            .setAutoCancel(true)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(1002, n)
    }

    /** هشدار کالاهای رو به اتمام */
    fun notifyLowStock(context: Context, count: Int, sampleNames: List<String>) {
        if (!permissionGranted(context) || count == 0) return
        val text = "$count کالا به حد هشدار موجودی رسیده است"
        val detail = buildString {
            append(text)
            if (sampleNames.isNotEmpty()) {
                append("\n")
                append(sampleNames.joinToString("، "))
                if (count > sampleNames.size) append(" و…")
            }
        }
        val n = NotificationCompat.Builder(context, CHANNEL_STOCK)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("کمبود موجودی انبار")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(detail))
            .setContentIntent(openAppIntent(context, "products"))
            .setAutoCancel(true)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(1004, n)
    }

    fun notifyBackupDone(context: Context) {
        if (!permissionGranted(context)) return
        val n = NotificationCompat.Builder(context, CHANNEL_BACKUP)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("پشتیبان‌گیری هفتگی انجام شد")
            .setContentText("نسخه پشتیبان محلی جدید ساخته شد")
            .setAutoCancel(true)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(1003, n)
    }
}
