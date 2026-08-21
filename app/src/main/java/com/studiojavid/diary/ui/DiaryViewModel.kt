package com.studiojavid.diary.ui

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.studiojavid.diary.data.local.Mood
import com.studiojavid.diary.data.repo.DiaryPage
import com.studiojavid.diary.data.repo.DiaryRepository
import com.studiojavid.diary.ui.components.DayMark
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
import java.io.File
import java.time.LocalDate

/** Which slice of the diary the list is showing. */
enum class DiaryFilter { ALL, FAVORITES, WITH_PHOTO }

/** Inclusive date window the calendar currently needs indicators for. */
data class DateRange(val start: LocalDate, val endInclusive: LocalDate)

data class DiaryUiState(
    /** The page of the selected day, or null when that day is still blank. */
    val page: DiaryPage? = null,
    val recent: List<DiaryPage> = emptyList(),
    val onThisDay: List<DiaryPage> = emptyList()
)

data class DiaryStats(
    val total: Int = 0,
    val streak: Int = 0,
    val thisMonth: Int = 0,
    val favorites: Int = 0,
    /** Whether a page exists for each of the last 7 days, oldest first. */
    val weekly: List<Boolean> = List(7) { false },
    val weeklyDates: List<LocalDate> = emptyList(),
    /** How many pages carry each mood, for the mood breakdown. */
    val moodCounts: Map<Mood, Int> = emptyMap()
)

@OptIn(ExperimentalCoroutinesApi::class)
class DiaryViewModel(private val repository: DiaryRepository) : ViewModel() {

    private val _today = MutableStateFlow(LocalDate.now())
    val today: StateFlow<LocalDate> = _today.asStateFlow()

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    private val _filter = MutableStateFlow(DiaryFilter.ALL)
    val filter: StateFlow<DiaryFilter> = _filter.asStateFlow()

    private val _visibleRange = MutableStateFlow(monthRangeOf(LocalDate.now()))

    /** Last deleted page, kept in memory so the snackbar can undo it. */
    private val _lastDeleted = MutableStateFlow<DiaryPage?>(null)
    val lastDeleted: StateFlow<DiaryPage?> = _lastDeleted.asStateFlow()

    val diary: StateFlow<DiaryUiState> =
        combine(
            _selectedDate.flatMapLatest { repository.pageOn(it) },
            repository.allPages,
            _today.flatMapLatest { repository.onThisDay(it) }
        ) { page, all, lookBack ->
            DiaryUiState(
                page = page,
                recent = all.take(RECENT_LIMIT),
                onThisDay = lookBack
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DiaryUiState())

    /**
     * Search and filter run over the whole diary rather than as separate
     * queries: the data set is a few hundred rows at most, and one pipeline
     * keeps the list and the counts from ever disagreeing.
     */
    val pages: StateFlow<List<DiaryPage>> =
        combine(repository.allPages, _filter, _query) { all, filter, query ->
            val q = query.trim()
            all.asSequence()
                .filter { page ->
                    when (filter) {
                        DiaryFilter.ALL -> true
                        DiaryFilter.FAVORITES -> page.favorite
                        DiaryFilter.WITH_PHOTO -> page.hasPhoto
                    }
                }
                .filter { page ->
                    q.isEmpty() ||
                        page.title.contains(q, ignoreCase = true) ||
                        page.body.contains(q, ignoreCase = true) ||
                        page.tags.any { it.contains(q, ignoreCase = true) }
                }
                .toList()
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Calendar indicators for the month currently on screen. */
    val dayMarks: StateFlow<Map<LocalDate, DayMark>> =
        _visibleRange.flatMapLatest { range ->
            repository.dayMarks(range.start, range.endInclusive).map { marks ->
                marks.associate {
                    LocalDate.ofEpochDay(it.date) to DayMark(Mood.from(it.mood), it.hasPhoto == 1)
                }
            }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyMap())

    val stats: StateFlow<DiaryStats> =
        combine(repository.allPages, repository.writtenDays, _today) { all, days, today ->
            val written = days.toSet()
            val weeklyDates = (6 downTo 0).map { today.minusDays(it.toLong()) }
            DiaryStats(
                total = all.size,
                streak = calculateStreak(written, today),
                thisMonth = all.count { it.date.year == today.year && it.date.month == today.month },
                favorites = all.count { it.favorite },
                weekly = weeklyDates.map { it in written },
                weeklyDates = weeklyDates,
                moodCounts = all.filter { it.mood != Mood.UNSET }.groupingBy { it.mood }.eachCount()
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DiaryStats())

    /**
     * Consecutive days with a page, ending today or yesterday.
     *
     * Yesterday counts as the anchor so the streak is not declared broken
     * merely because the user has not written *yet* today.
     */
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
        // A diary can be back-filled but not pre-filled: a page dated in the
        // future is not a diary entry yet.
        _selectedDate.value = minOf(date, _today.value)
    }

    fun setVisibleMonth(first: LocalDate, last: LocalDate) {
        _visibleRange.value = DateRange(first.minusDays(7), last.plusDays(7))
    }

    fun setQuery(value: String) { _query.value = value }

    fun setFilter(value: DiaryFilter) { _filter.value = value }

    fun savePage(
        date: LocalDate,
        title: String,
        body: String,
        mood: Mood,
        tags: List<String>,
        photo: String,
        favorite: Boolean
    ) = viewModelScope.launch {
        repository.savePage(date, title, body, mood, tags, photo, favorite)
    }

    fun toggleFavorite(page: DiaryPage) = viewModelScope.launch {
        repository.setFavorite(page.id, !page.favorite)
    }

    fun deletePage(page: DiaryPage) = viewModelScope.launch {
        _lastDeleted.value = page
        repository.deletePage(page.id)
    }

    fun undoDelete() = viewModelScope.launch {
        _lastDeleted.value?.let { repository.restorePage(it) }
        _lastDeleted.value = null
    }

    fun clearLastDeleted() { _lastDeleted.value = null }

    /**
     * Copies a picked image into private storage and hands the stored name back
     * through [onImported]; the editor keeps it in its draft until save.
     */
    fun importPhoto(source: Uri, onImported: (String?) -> Unit) = viewModelScope.launch {
        onImported(repository.importPhoto(source))
    }

    fun photoFile(name: String): File? = repository.photoFile(name)

    companion object {
        private const val RECENT_LIMIT = 20

        fun monthRangeOf(date: LocalDate): DateRange {
            val first = date.withDayOfMonth(1).minusDays(10)
            val last = date.withDayOfMonth(date.lengthOfMonth()).plusDays(10)
            return DateRange(first, last)
        }

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer { DiaryViewModel(app().diaryRepository) }
        }
    }
}
