package com.studiojavid.memory.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.studiojavid.memory.data.repo.BirthdayPerson
import com.studiojavid.memory.data.repo.BirthdayRepository
import com.studiojavid.memory.data.repo.GiftIdea
import com.studiojavid.memory.data.repo.NoteRepository
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
    private val noteRepository: NoteRepository
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
     * Files a gift idea as a note so it survives outside the person's page and
     * can be found from the notes tab. [body] carries the whose-and-when
     * context the caller composed from resources.
     */
    fun giftIdeaToNote(title: String, body: String) = viewModelScope.launch {
        if (title.isBlank()) return@launch
        noteRepository.saveNote(title = title, body = body, notebookId = null)
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = app()
                BirthdayViewModel(app.birthdayRepository, app.noteRepository)
            }
        }
    }
}
