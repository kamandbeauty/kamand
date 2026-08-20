package com.studiojavid.memory.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.studiojavid.memory.MainActivity
import com.studiojavid.memory.R
import com.studiojavid.memory.data.repo.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * "Today" home-screen widget.
 *
 * Reads straight from the same Room database as the app — there is no separate
 * cache to fall out of sync. Updates are event-driven ([notifyChanged] is
 * called whenever the data layer mutates), so nothing polls in the background.
 */
class TodayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        // Room refuses blocking queries on the main thread (and onUpdate runs
        // there), so the summary is read on IO and the views pushed afterwards.
        val appContext = context.applicationContext
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val summary = WidgetData.summary(appContext)
                ids.forEach { id -> render(appContext, manager, id, summary) }
            } finally {
                pending.finish()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE) {
            val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L)
            if (taskId <= 0) return
            val pending = goAsync()
            CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                try {
                    val repo = TaskRepository(context.applicationContext)
                    val current = com.studiojavid.memory.data.local.MemoryDatabase
                        .get(context.applicationContext).taskDao().findById(taskId)
                    if (current != null) {
                        repo.setCompleted(taskId, !current.isCompleted)
                    }
                    notifyChanged(context.applicationContext)
                } finally {
                    pending.finish()
                }
            }
        }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        summary: WidgetData.Summary
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today)

        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_add, openAppIntent(context, quickAdd = true))

        // The list itself is served by TodayWidgetService (RemoteViewsFactory).
        val serviceIntent = Intent(context, TodayWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        // A single template intent is filled in per row by the factory.
        val toggleTemplate = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, TodayWidgetProvider::class.java).setAction(ACTION_TOGGLE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.widget_list, toggleTemplate)

        views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_today_title))
        views.setTextViewText(R.id.widget_date, summary.dateLabel)
        views.setTextViewText(R.id.widget_progress, summary.progressLabel)
        views.setProgressBar(R.id.widget_progress_bar, summary.total.coerceAtLeast(1), summary.done, false)

        manager.updateAppWidget(widgetId, views)
        manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
    }

    private fun openAppIntent(context: Context, quickAdd: Boolean = false): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (quickAdd) putExtra(MainActivity.EXTRA_QUICK_ADD, true)
            action = if (quickAdd) "memory.QUICK_ADD" else Intent.ACTION_MAIN
        }
        return PendingIntent.getActivity(
            context,
            if (quickAdd) 1 else 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        const val ACTION_TOGGLE = "com.studiojavid.memory.widget.TOGGLE"
        const val EXTRA_TASK_ID = "widget_task_id"

        /** Refreshes every placed widget. Cheap, and only called on real changes. */
        fun notifyChanged(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
            if (ids.isEmpty()) return
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
            context.sendBroadcast(
                Intent(context, TodayWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }
}
