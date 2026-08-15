package com.roozi.app.data.repo

import android.content.Context
import com.roozi.app.data.local.CategoryEntity
import com.roozi.app.data.local.DayCount
import com.roozi.app.data.local.Priority
import com.roozi.app.data.local.RooziDatabase
import com.roozi.app.data.local.TaskEntity
import com.roozi.app.notifications.ReminderScheduler
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
    private val db: RooziDatabase = RooziDatabase.get(context),
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
        dueDate: LocalDate? = LocalDate.now(),
        dueTimeMinutes: Int? = null,
        priority: Priority = Priority.MEDIUM,
        reminderEnabled: Boolean = false
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
            sortOrder = existing?.sortOrder ?: taskDao.nextSortOrder()
        )
        val newId = if (id == 0L) taskDao.insert(entity) else {
            taskDao.update(entity); id
        }
        syncReminder(entity.copy(id = newId))
        return newId
    }

    /** Reminder fires at the task time, or at 9:00 when the task has no time. */
    private fun reminderTimestamp(date: LocalDate?, minutes: Int?, enabled: Boolean): Long? {
        if (!enabled || date == null) return null
        val m = minutes ?: (9 * 60)
        return date.atStartOfDay(ZoneId.systemDefault())
            .plusMinutes(m.toLong())
            .toInstant()
            .toEpochMilli()
    }

    private fun syncReminder(task: TaskEntity) {
        val at = task.reminderTime
        if (task.reminderEnabled && !task.isCompleted && at != null && at > System.currentTimeMillis()) {
            scheduler.schedule(task.id, task.title, at)
        } else {
            scheduler.cancel(task.id)
        }
    }

    suspend fun setCompleted(taskId: Long, completed: Boolean) {
        val task = taskDao.findById(taskId) ?: return
        val updated = task.copy(
            isCompleted = completed,
            completedAt = if (completed) System.currentTimeMillis() else null
        )
        taskDao.update(updated)
        syncReminder(updated)
    }

    suspend fun delete(taskId: Long) {
        scheduler.cancel(taskId)
        taskDao.deleteById(taskId)
    }

    /** Re-inserts a previously deleted task (undo). Keeps the original id. */
    suspend fun restore(task: Task) {
        val entity = task.toEntity()
        taskDao.insert(entity)
        syncReminder(entity)
    }

    suspend fun deleteAllCompleted() = taskDao.deleteCompleted()

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
    }
}
