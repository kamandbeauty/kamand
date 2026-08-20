package com.javidstudio.app2.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.javidstudio.app2.MainActivity
import com.javidstudio.app2.R

/** A single tap opens the app straight into the add-task sheet. */
class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "app2.QUICK_ADD"
            putExtra(MainActivity.EXTRA_QUICK_ADD, true)
        }
        val pending = PendingIntent.getActivity(
            context, 2, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            views.setOnClickPendingIntent(R.id.quick_add_root, pending)
            views.setTextViewText(R.id.quick_add_label, context.getString(R.string.widget_quick_add))
            manager.updateAppWidget(id, views)
        }
    }
}
