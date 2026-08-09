package ir.factoryar.app.widget

import android.content.Context
import android.content.Intent
import androidx.glance.action.Action
import androidx.glance.appwidget.action.actionStartActivity
import ir.factoryar.app.MainActivity

/**
 * اکشن‌های ویجت — هرکدام MainActivity را با یک مقصد مشخص باز می‌کنند.
 * کلید `navigate_to` در MainActivity خوانده می‌شود.
 */
object WidgetActions {

    const val EXTRA_NAVIGATE = "navigate_to"

    /** میان‌بر صدور فاکتور جدید: مستقیم فرم فاکتور باز می‌شود */
    const val TARGET_NEW_INVOICE = "new_invoice"
    const val TARGET_DASHBOARD = "dashboard"
    const val TARGET_INVOICES = "invoices"

    fun newInvoice(context: Context): Action = intentAction(context, TARGET_NEW_INVOICE)
    fun openDashboard(context: Context): Action = intentAction(context, TARGET_DASHBOARD)
    fun openInvoices(context: Context): Action = intentAction(context, TARGET_INVOICES)

    private fun intentAction(context: Context, target: String): Action = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            // data منحصربه‌فرد تا PendingIntentها با هم قاطی نشوند
            data = android.net.Uri.parse("factoryar://widget/$target")
            putExtra(EXTRA_NAVIGATE, target)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        },
    )
}
