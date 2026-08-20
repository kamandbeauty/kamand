package com.javidstudio.app2.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.javidstudio.app2.data.repo.BirthdayPerson
import com.javidstudio.app2.data.repo.BirthdayRepository
import com.javidstudio.app2.data.repo.GiftIdea
import com.javidstudio.app2.data.repo.TaskRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate

@OptIn(ExperimentalCoroutinesApi::class)
class BirthdayViewModel(
    private val repository: BirthdayRepository,
    private val taskRepository: TaskRepository
) : ViewModel() {

    val people: StateFlow<List<BirthdayPerson>> = repository.people
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Person currently open in the details screen. */
    private val _openPersonId = MutableStateFlow<Long?>(null)
    val openPersonId: StateFlow<Long?> = _openPersonId.asStateFlow()

    val openPerson: StateFlow<BirthdayPerson?> = _openPersonId
        .flatMapLatest { id ->
            if (id == null) kotlinx.coroutines.flow.flowOf(null) else repository.person(id)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val giftIdeas: StateFlow<List<GiftIdea>> = _openPersonId
        .flatMapLatest { id ->
            if (id == null) kotlinx.coroutines.flow.flowOf(emptyList())
            else repository.giftIdeas(id)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Day selected in the birthday calendar. */
    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    fun openPerson(id: Long?) { _openPersonId.value = id }

    fun selectDate(date: LocalDate) { _selectedDate.value = date }

    fun savePerson(
        id: Long,
        name: String,
        birthMonth: Int,
        birthDay: Int,
        birthYear: Int?,
        relationship: String,
        avatar: String,
        notes: String,
        reminderEnabled: Boolean,
        reminderOffset: Int
    ) = viewModelScope.launch {
        if (name.isBlank()) return@launch
        repository.savePerson(
            id = id,
            name = name,
            birthMonth = birthMonth,
            birthDay = birthDay,
            birthYear = birthYear,
            relationship = relationship,
            avatar = avatar,
            notes = notes,
            reminderEnabled = reminderEnabled,
            reminderOffset = reminderOffset
        )
    }

    fun deletePerson(person: BirthdayPerson) = viewModelScope.launch {
        if (_openPersonId.value == person.id) _openPersonId.value = null
        repository.deletePerson(person.id)
    }

    fun setFavoriteMessage(personId: Long, messageId: Int) = viewModelScope.launch {
        repository.setFavoriteMessage(personId, messageId)
    }

    fun addGiftIdea(personId: Long, title: String) = viewModelScope.launch {
        if (title.isNotBlank()) repository.addGiftIdea(personId, title)
    }

    fun toggleGiftIdea(idea: GiftIdea) = viewModelScope.launch {
        repository.updateGiftIdea(idea.copy(isCompleted = !idea.isCompleted))
    }

    fun deleteGiftIdea(idea: GiftIdea) = viewModelScope.launch {
        repository.deleteGiftIdea(idea.id)
    }

    /**
     * Turns a gift idea into a real task, dated a few days before the birthday
     * so there is time to actually buy it.
     */
    fun giftIdeaToTask(idea: GiftIdea, person: BirthdayPerson, title: String) =
        viewModelScope.launch {
            val birthday = LocalDate.now().plusDays(person.daysUntil.toLong())
            val due = birthday.minusDays(GIFT_LEAD_DAYS)
            val dueDate = if (due.isBefore(LocalDate.now())) LocalDate.now() else due
            taskRepository.saveTask(title = title, dueDate = dueDate)
        }

    companion object {
        /** Buy the gift a few days early, not on the day itself. */
        private const val GIFT_LEAD_DAYS = 2L

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = app()
                BirthdayViewModel(app.birthdayRepository, app.repository)
            }
        }
    }
}
