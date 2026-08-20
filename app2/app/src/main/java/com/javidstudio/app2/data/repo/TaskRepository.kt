package com.javidstudio.app2.data.repo

import android.content.Context
import com.javidstudio.app2.core.recurrence.RecurrenceRule
import com.javidstudio.app2.data.local.CategoryEntity
import com.javidstudio.app2.data.local.DayCount
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.local.App2Database
import com.javidstudio.app2.data.local.TaskEntity
import com.javidstudio.app2.notifications.ReminderScheduler
import com.javidstudio.app2.widget.TodayWidgetProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import java.time.ZoneId

/**
 * Single source of truth for tasks & categories.
 *
 * Everything is offline; the repository additionally owns reminder scheduling
 * so a task and its alarm can never drift apart.
 */
class TaskRepository(
    private val context: Context,
    private val db: App2Database = App2Database.get(context),
    private val scheduler: ReminderScheduler = ReminderScheduler(context)
) {
    private val taskDao = db.taskDao()
    private val categoryDao = db.categoryDao()

    val categories: Flow<List<Category>> = categoryDao.observeAll().map { list ->
        list.map { it.toDomain() }
    }

    private fun categoryMap(): Flow<Map<Long, Category>> = categories.map { list -> list.associateBy { it.id } }

    val allTasks: Flow<List<Task>> = taskDao.observeAll().combineWithCategories()

    fun tasksOn(date: LocalDate): Flow<List<Task>> =
        taskDao.observeByDate(date.toEpochDay()).combineWithCategories()

    fun todayAgenda(date: LocalDate): Flow<List<Task>> =
        taskDao.observeTodayAgenda(date.toEpochDay()).combineWithCategories()

    val completedTasks: Flow<List<Task>> = taskDao.observeCompleted().combineWithCategories()

    /** Backlog of tasks without a date. */
    val undatedTasks: Flow<List<Task>> = taskDao.observeUndated().combineWithCategories()

    fun dayCounts(from: LocalDate, to: LocalDate): Flow<List<DayCount>> =
        taskDao.observeDayCounts(from.toEpochDay(), to.toEpochDay())

    val completionTimes: Flow<List<Long>> = taskDao.observeCompletionTimes()

    private fun Flow<List<TaskEntity>>.combineWithCategories(): Flow<List<Task>> =
        combine(categoryMap()) { tasks, cats -> tasks.map { it.toDomain(cats) } }

    // ------------------------------------------------------------------
    // Mutations
    // ------------------------------------------------------------------

    suspend fun ensureSeeded() {
        if (categoryDao.count() == 0) categoryDao.insertAll(DefaultCategories.seed())
    }

    suspend fun saveTask(
        id: Long = 0,
        title: String,
        description: String = "",
        categoryId: Long? = null,
        /** Null is a first-class value: the task simply has no date. */
        dueDate: LocalDate? = null,
        dueTimeMinutes: Int? = null,
        priority: Priority = Priority.MEDIUM,
        reminderEnabled: Boolean = false,
        repeat: RecurrenceRule = RecurrenceRule.None
    ): Long {
        val existing = if (id != 0L) taskDao.findById(id) else null
        val reminderAt = reminderTimestamp(dueDate, dueTimeMinutes, reminderEnabled)
        val entity = TaskEntity(
            id = id,
            title = title.trim(),
            description = description.trim(),
            categoryId = categoryId,
            createdAt = existing?.createdAt ?: System.currentTimeMillis(),
            dueDate = dueDate?.toEpochDay(),
            dueTime = dueTimeMinutes,
            isCompleted = existing?.isCompleted ?: false,
            completedAt = existing?.completedAt,
            priority = priority.value,
            reminderEnabled = reminderEnabled && reminderAt != null,
            reminderTime = reminderAt,
            repeatRule = repeat.serialize(),
            sortOrder = existing?.sortOrder ?: taskDao.nextSortOrder()
        )
        val newId = if (id == 0L) taskDao.insert(entity) else {
            taskDao.update(entity); id
        }
        syncReminder(entity.copy(id = newId))
        notifyWidgets()
        return newId
    }

    /**
     * Resolves when a reminder should fire.
     *
     * Rules that matter in practice:
     *  - A task with no date still gets a reminder: it means "today".
     *  - A task with no time defaults to 9:00.
     *  - If that moment has already passed (e.g. it is 14:00 and the default is
     *    9:00 today, or the user picks an earlier time), the reminder rolls to
     *    the next day instead of being silently dropped — previously the alarm
     *    was simply never scheduled and the user saw nothing.
     */
    private fun reminderTimestamp(date: LocalDate?, minutes: Int?, enabled: Boolean): Long? {
        if (!enabled) return null
        val zone = ZoneId.systemDefault()
        val day = date ?: LocalDate.now(zone)
        val m = minutes ?: DEFAULT_REMINDER_MINUTES

        var moment = day.atStartOfDay(zone).plusMinutes(m.toLong())
        if (moment.toInstant().toEpochMilli() <= System.currentTimeMillis()) {
            // Only roll forward when the user did not deliberately pick a past
            // day; a reminder on an explicitly past date is meaningless.
            if (date == null || !day.isBefore(LocalDate.now(zone))) {
                moment = moment.plusDays(1)
            } else {
                return null
            }
        }
        return moment.toInstant().toEpochMilli()
    }

    /**
     * Pushes a refresh to any placed home-screen widget. Called only from real
     * mutations, so widgets stay in sync without any background polling.
     */
    private fun notifyWidgets() {
        runCatching { TodayWidgetProvider.notifyChanged(context) }
    }

    private fun syncReminder(task: TaskEntity) {
        val at = task.reminderTime
        if (task.reminderEnabled && !task.isCompleted && at != null && at > System.currentTimeMillis()) {
            scheduler.schedule(task.id, task.title, at)
        } else {
            scheduler.cancel(task.id)
        }
    }

    /**
     * Completing a repeating task closes the current occurrence and immediately
     * schedules the next one, so a recurring task never disappears from the plan.
     */
    suspend fun setCompleted(taskId: Long, completed: Boolean) {
        val task = taskDao.findById(taskId) ?: return
        val updated = task.copy(
            isCompleted = completed,
            completedAt = if (completed) System.currentTimeMillis() else null
        )
        taskDao.update(updated)
        syncReminder(updated)

        if (completed) rollForwardIfRepeating(updated)
        notifyWidgets()
    }

    private suspend fun rollForwardIfRepeating(task: TaskEntity) {
        val rule = RecurrenceRule.parse(task.repeatRule)
        if (!rule.isRepeating) return
        val base = task.dueDate?.let { LocalDate.ofEpochDay(it) } ?: LocalDate.now()

        // If the task is ticked off late, walking one step could still land in
        // the past. Advance until the occurrence is today or later so a
        // long-neglected repeating task reappears on the plan, not behind it.
        val today = LocalDate.now()
        var next = rule.nextAfter(base) ?: return
        var guard = 0
        while (next.isBefore(today) && guard < MAX_ROLL_FORWARD_STEPS) {
            next = rule.nextAfter(next) ?: return
            guard++
        }

        val nextEntity = task.copy(
            id = 0,
            dueDate = next.toEpochDay(),
            isCompleted = false,
            completedAt = null,
            createdAt = System.currentTimeMillis(),
            reminderTime = reminderTimestamp(next, task.dueTime, task.reminderEnabled)
        )
        val newId = taskDao.insert(nextEntity)
        syncReminder(nextEntity.copy(id = newId))
    }

    /** Moves a task to another day (or clears its date when [date] is null). */
    suspend fun moveToDate(taskId: Long, date: LocalDate?) {
        val task = taskDao.findById(taskId) ?: return
        val reminderAt = reminderTimestamp(date, task.dueTime, task.reminderEnabled)
        val updated = task.copy(
            dueDate = date?.toEpochDay(),
            reminderTime = reminderAt,
            reminderEnabled = task.reminderEnabled && reminderAt != null
        )
        taskDao.update(updated)
        syncReminder(updated)
        notifyWidgets()
    }

    /** Persists a drag & drop reordering. */
    suspend fun applyOrder(ids: List<Long>) {
        taskDao.applyOrder(ids)
        notifyWidgets()
    }

    suspend fun delete(taskId: Long) {
        scheduler.cancel(taskId)
        taskDao.deleteById(taskId)
        notifyWidgets()
    }

    /** Re-inserts a previously deleted task (undo). Keeps the original id. */
    suspend fun restore(task: Task) {
        val entity = task.toEntity()
        taskDao.insert(entity)
        syncReminder(entity)
        notifyWidgets()
    }

    suspend fun deleteAllCompleted() {
        taskDao.deleteCompleted()
        notifyWidgets()
    }

    suspend fun addCategory(name: String, icon: String, color: Int): Long =
        categoryDao.upsert(CategoryEntity(name = name.trim(), icon = icon, color = color))

    suspend fun deleteCategory(category: Category) {
        categoryDao.delete(
            CategoryEntity(
                id = category.id,
                name = category.rawName,
                icon = category.icon,
                color = category.color,
                builtInKey = category.builtInKey
            )
        )
    }

    /** Re-arms every future reminder — used after a reboot or a restore. */
    suspend fun rescheduleAllReminders() {
        taskDao.pendingReminders().forEach { syncReminder(it) }
    }

    // ------------------------------------------------------------------
    // Backup support
    // ------------------------------------------------------------------

    suspend fun snapshot(): Pair<List<TaskEntity>, List<CategoryEntity>> {
        val tasks = taskDao.observeAll().first()
        val cats = categoryDao.observeAll().first()
        return tasks to cats
    }

    suspend fun replaceAll(tasks: List<TaskEntity>, categories: List<CategoryEntity>) {
        taskDao.clear()
        categoryDao.replaceAll(categories)
        taskDao.insertAll(tasks)
        rescheduleAllReminders()
        notifyWidgets()
    }

    private companion object {
        /** Safety valve when catching up a long-neglected repeating task. */
        const val MAX_ROLL_FORWARD_STEPS = 1200

        /** Time of day used when a task has a reminder but no explicit time. */
        const val DEFAULT_REMINDER_MINUTES = 9 * 60
    }
}
