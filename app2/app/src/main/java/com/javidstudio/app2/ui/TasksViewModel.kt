package com.javidstudio.app2.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.javidstudio.app2.core.recurrence.RecurrenceRule
import com.javidstudio.app2.data.local.Priority
import com.javidstudio.app2.data.repo.Category
import com.javidstudio.app2.data.repo.Task
import com.javidstudio.app2.data.repo.TaskRepository
import com.javidstudio.app2.ui.components.DayLoad
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

enum class TaskFilter { ALL, TODAY, NO_DATE, UNDONE, DONE, IMPORTANT }

/** Inclusive date window the calendar currently needs indicators for. */
data class DateRange(val start: LocalDate, val endInclusive: LocalDate)

data class TodayUiState(
    val tasks: List<Task> = emptyList(),
    val total: Int = 0,
    val done: Int = 0
) {
    /** Scheduled tasks with a clock time — the actual day plan. */
    val timed: List<Task> get() = tasks.filter { !it.isCompleted && it.hasTime }

    /** Dated for today but without a time: no fake clock values. */
    val anytime: List<Task> get() = tasks.filter { !it.isCompleted && !it.hasTime }

    val completedTasks: List<Task> get() = tasks.filter { it.isCompleted }

    val remaining: Int get() = (total - done).coerceAtLeast(0)
    val progress: Float get() = if (total == 0) 0f else done.toFloat() / total
    val percent: Int get() = (progress * 100).toInt()
    val allDone: Boolean get() = total > 0 && done == total
}

data class StatsUiState(
    val completed: Int = 0,
    val pending: Int = 0,
    val successRate: Int = 0,
    val streak: Int = 0,
    /** Completion counts for the last 7 days, oldest first. */
    val weekly: List<Int> = List(7) { 0 },
    val weeklyDates: List<LocalDate> = emptyList()
)

@OptIn(ExperimentalCoroutinesApi::class)
class TasksViewModel(private val repository: TaskRepository) : ViewModel() {

    private val _today = MutableStateFlow(LocalDate.now())
    val today: StateFlow<LocalDate> = _today.asStateFlow()

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    private val _filter = MutableStateFlow(TaskFilter.ALL)
    val filter: StateFlow<TaskFilter> = _filter.asStateFlow()

    private val _visibleRange = MutableStateFlow(monthRangeOf(LocalDate.now()))

    /** Last deleted task, kept in memory so the snackbar can undo it. */
    private val _lastDeleted = MutableStateFlow<Task?>(null)
    val lastDeleted: StateFlow<Task?> = _lastDeleted.asStateFlow()

    private val _celebrate = MutableStateFlow(false)
    val celebrate: StateFlow<Boolean> = _celebrate.asStateFlow()
    private var celebratedForDay: LocalDate? = null

    val categories: StateFlow<List<Category>> = repository.categories
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val todayState: StateFlow<TodayUiState> = _today
        .flatMapLatest { date -> repository.todayAgenda(date) }
        .map { tasks ->
            TodayUiState(
                tasks = tasks,
                total = tasks.size,
                done = tasks.count { it.isCompleted }
            )
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TodayUiState())

    /** The "بدون تاریخ" backlog. */
    val undated: StateFlow<List<Task>> = repository.undatedTasks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val selectedDayTasks: StateFlow<List<Task>> = _selectedDate
        .flatMapLatest { repository.tasksOn(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val dayLoads: StateFlow<Map<LocalDate, DayLoad>> = _visibleRange
        .flatMapLatest { range -> repository.dayCounts(range.start, range.endInclusive) }
        .map { counts ->
            counts.associate { LocalDate.ofEpochDay(it.dueDate) to DayLoad(it.total, it.done) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyMap())

    val completed: StateFlow<List<Task>> = repository.completedTasks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Search + filter results over all tasks. */
    val searchResults: StateFlow<List<Task>> =
        combine(repository.allTasks, _query, _filter, _today) { tasks, query, filter, today ->
            val q = query.trim()
            tasks.asSequence()
                .filter { task ->
                    q.isEmpty() ||
                        task.title.contains(q, ignoreCase = true) ||
                        task.description.contains(q, ignoreCase = true) ||
                        task.category?.rawName?.contains(q, ignoreCase = true) == true
                }
                .filter { task ->
                    when (filter) {
                        TaskFilter.ALL -> true
                        TaskFilter.TODAY -> task.dueDate == today
                        TaskFilter.NO_DATE -> task.dueDate == null
                        TaskFilter.UNDONE -> !task.isCompleted
                        TaskFilter.DONE -> task.isCompleted
                        TaskFilter.IMPORTANT -> task.priority == Priority.HIGH
                    }
                }
                .toList()
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val stats: StateFlow<StatsUiState> =
        combine(repository.allTasks, repository.completionTimes, _today) { tasks, completions, today ->
            val completed = tasks.count { it.isCompleted }
            val pending = tasks.size - completed
            val rate = if (tasks.isEmpty()) 0 else (completed * 100) / tasks.size
            val zone = ZoneId.systemDefault()
            val completionDays = completions.map {
                java.time.Instant.ofEpochMilli(it).atZone(zone).toLocalDate()
            }.toSet()
            val weeklyDates = (6 downTo 0).map { today.minusDays(it.toLong()) }
            val weekly = weeklyDates.map { day ->
                completions.count { java.time.Instant.ofEpochMilli(it).atZone(zone).toLocalDate() == day }
            }
            StatsUiState(
                completed = completed,
                pending = pending,
                successRate = rate,
                streak = calculateStreak(completionDays, today),
                weekly = weekly,
                weeklyDates = weeklyDates
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StatsUiState())

    /** Consecutive days (ending today or yesterday) with at least one completion. */
    private fun calculateStreak(days: Set<LocalDate>, today: LocalDate): Int {
        var cursor = if (days.contains(today)) today else today.minusDays(1)
        if (!days.contains(cursor)) return 0
        var streak = 0
        while (days.contains(cursor)) {
            streak++
            cursor = cursor.minusDays(1)
        }
        return streak
    }

    fun refreshToday() {
        val now = LocalDate.now()
        if (_today.value != now) {
            _today.value = now
            if (_selectedDate.value < now) _selectedDate.value = now
        }
    }

    fun selectDate(date: LocalDate) {
        _selectedDate.value = date
    }

    fun setVisibleMonth(first: LocalDate, last: LocalDate) {
        _visibleRange.value = DateRange(first.minusDays(7), last.plusDays(7))
    }

    fun setQuery(value: String) {
        _query.value = value
    }

    fun setFilter(value: TaskFilter) {
        _filter.value = value
    }

    fun toggleTask(task: Task) = viewModelScope.launch {
        repository.setCompleted(task.id, !task.isCompleted)
    }

    fun deleteTask(task: Task) = viewModelScope.launch {
        _lastDeleted.value = task
        repository.delete(task.id)
    }

    fun undoDelete() = viewModelScope.launch {
        _lastDeleted.value?.let { repository.restore(it) }
        _lastDeleted.value = null
    }

    fun clearLastDeleted() {
        _lastDeleted.value = null
    }

    fun deleteAllCompleted() = viewModelScope.launch { repository.deleteAllCompleted() }

    fun saveTask(
        id: Long,
        title: String,
        description: String,
        categoryId: Long?,
        dueDate: LocalDate?,
        dueTimeMinutes: Int?,
        priority: Priority,
        reminderEnabled: Boolean,
        repeat: RecurrenceRule = RecurrenceRule.None
    ) = viewModelScope.launch {
        repository.saveTask(
            id = id,
            title = title,
            description = description,
            categoryId = categoryId,
            dueDate = dueDate,
            dueTimeMinutes = dueTimeMinutes,
            priority = priority,
            reminderEnabled = reminderEnabled,
            repeat = repeat
        )
    }

    /**
     * The fastest possible path: a title and nothing else.
     * No date, no time, no reminder — exactly what "خرید نان" needs.
     */
    fun quickAdd(title: String, date: LocalDate? = null) = viewModelScope.launch {
        if (title.isBlank()) return@launch
        repository.saveTask(title = title, dueDate = date)
    }

    /** Move a task to another day, or clear its date entirely. */
    fun moveTask(task: Task, date: LocalDate?) = viewModelScope.launch {
        repository.moveToDate(task.id, date)
    }

    fun setReminder(task: Task, enabled: Boolean) = viewModelScope.launch {
        repository.saveTask(
            id = task.id,
            title = task.title,
            description = task.description,
            categoryId = task.category?.id,
            dueDate = task.dueDate,
            dueTimeMinutes = task.dueTimeMinutes,
            priority = task.priority,
            reminderEnabled = enabled,
            repeat = task.repeat
        )
    }

    /** Persist a drag & drop reordering of the visible list. */
    fun persistOrder(ids: List<Long>) = viewModelScope.launch {
        repository.applyOrder(ids)
    }

    fun addCategory(name: String, icon: String, color: Int) = viewModelScope.launch {
        repository.addCategory(name, icon, color)
    }

    fun deleteCategory(category: Category) = viewModelScope.launch {
        repository.deleteCategory(category)
    }

    /** Fires the celebration at most once per day, when the last task is ticked. */
    fun onProgressChanged(state: TodayUiState) {
        val day = _today.value
        if (state.allDone && celebratedForDay != day) {
            celebratedForDay = day
            _celebrate.value = true
        } else if (!state.allDone && celebratedForDay == day) {
            celebratedForDay = null
        }
    }

    fun dismissCelebration() {
        _celebrate.value = false
    }

    private fun monthRangeOf(date: LocalDate): DateRange =
        DateRange(date.minusDays(45), date.plusDays(45))

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer { TasksViewModel(app().repository) }
        }
    }
}
