package com.roozi.app.widget

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.roozi.app.R
import com.roozi.app.core.date.DateFormatter
import com.roozi.app.core.util.PersianNumbers
import com.roozi.app.data.local.RooziDatabase
import com.roozi.app.data.local.TaskEntity
import com.roozi.app.data.prefs.AppLanguage
import java.time.LocalDate

/** Feeds the widget's task list. */
class TodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TodayWidgetFactory(applicationContext)
}

private class TodayWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var tasks: List<TaskEntity> = emptyList()
    private var formatter: DateFormatter = DateFormatter(context, persian = true)

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val language = WidgetData.language(context)
        val localized = WidgetData.localizedContext(context, language)
        formatter = DateFormatter(localized, language.isPersian)
        tasks = RooziDatabase.get(context).taskDao()
            .todayAgendaBlocking(LocalDate.now().toEpochDay())
            .take(MAX_ROWS)
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.widget_row)
        val views = RemoteViews(context.packageName, R.layout.widget_row)

        views.setTextViewText(R.id.row_title, task.title)
        views.setTextViewText(R.id.row_check, if (task.isCompleted) "✓" else "○")

        // Strike-through and dimming for completed rows.
        if (task.isCompleted) {
            views.setInt(R.id.row_title, "setPaintFlags", STRIKE_FLAGS)
            views.setTextColor(R.id.row_title, Color.parseColor("#8A8595"))
        } else {
            views.setInt(R.id.row_title, "setPaintFlags", BASE_FLAGS)
            views.setTextColor(R.id.row_title, Color.parseColor("#241F2E"))
        }

        val time = task.dueTime
        if (time != null) {
            views.setTextViewText(R.id.row_time, formatter.time(time))
            views.setViewVisibility(R.id.row_time, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.row_time, View.GONE)
        }

        // Tapping a row toggles completion via the provider's template intent.
        views.setOnClickFillInIntent(
            R.id.row_root,
            Intent().putExtra(TodayWidgetProvider.EXTRA_TASK_ID, task.id)
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = tasks.getOrNull(position)?.id ?: position.toLong()
    override fun hasStableIds(): Boolean = true

    private companion object {
        const val MAX_ROWS = 12
        val BASE_FLAGS: Int = android.graphics.Paint.ANTI_ALIAS_FLAG
        val STRIKE_FLAGS: Int =
            android.graphics.Paint.ANTI_ALIAS_FLAG or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
    }
}

/** Shared helpers for widget rendering. */
object WidgetData {

    data class Summary(val done: Int, val total: Int, val progressLabel: String)

    fun language(context: Context): AppLanguage {
        // DataStore is async; the widget needs a synchronous answer, so we fall
        // back to the device locale, which the user has already matched in-app.
        val tag = context.resources.configuration.locales[0].language
        return if (tag == "en") AppLanguage.ENGLISH else AppLanguage.PERSIAN
    }

    fun localizedContext(context: Context, language: AppLanguage): Context {
        val locale = java.util.Locale(language.tag)
        val config = android.content.res.Configuration(context.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        return context.createConfigurationContext(config)
    }

    fun summary(context: Context): Summary {
        val language = language(context)
        val localized = localizedContext(context, language)
        val tasks = RooziDatabase.get(context).taskDao()
            .todayAgendaBlocking(LocalDate.now().toEpochDay())
        val done = tasks.count { it.isCompleted }
        val total = tasks.size
        val persian = language.isPersian
        val label = localized.getString(
            R.string.widget_progress,
            PersianNumbers.format(done, persian),
            PersianNumbers.format(total, persian)
        )
        return Summary(done, total, label)
    }
}
