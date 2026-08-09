package com.forushyar.app.ui.customers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.repository.CustomerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

data class CustomerFormState(
    val id: Long = 0,
    val name: String = "",
    val phone: String = "",
    val instagramId: String = "",
    val address: String = "",
    val note: String = "",
    val createdDate: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val nameError: Boolean = false,
    val loadFailed: Boolean = false
)

sealed interface CustomerFormEvent {
    data object Saved : CustomerFormEvent
    data object SaveFailed : CustomerFormEvent
}

/** فرم مشترک ثبت و ویرایش مشتری. شماره تلفن عمداً اجباری نیست. */
@HiltViewModel
class CustomerFormViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: CustomerRepository
) : ViewModel() {

    private val customerId: Long = savedStateHandle.get<Long>("customerId") ?: 0L
    private val _state = MutableStateFlow(CustomerFormState(isLoading = customerId > 0))
    val state: StateFlow<CustomerFormState> = _state.asStateFlow()

    private val _events = Channel<CustomerFormEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    init {
        if (customerId > 0) loadCustomer()
    }

    private fun loadCustomer() {
        viewModelScope.launch {
            val customer = repository.observeById(customerId).first()
            _state.value = if (customer == null) {
                _state.value.copy(isLoading = false, loadFailed = true)
            } else {
                CustomerFormState(
                    id = customer.id,
                    name = customer.name,
                    phone = customer.phone,
                    instagramId = customer.instagramId,
                    address = customer.address,
                    note = customer.note,
                    createdDate = customer.createdDate
                )
            }
        }
    }

    fun onNameChange(value: String) = update { copy(name = value, nameError = false) }
    fun onPhoneChange(value: String) = update { copy(phone = value) }
    fun onInstagramIdChange(value: String) = update { copy(instagramId = value) }
    fun onAddressChange(value: String) = update { copy(address = value) }
    fun onNoteChange(value: String) = update { copy(note = value) }

    private fun update(block: CustomerFormState.() -> CustomerFormState) {
        _state.value = _state.value.block()
    }

    fun save() {
        val current = _state.value
        if (current.name.isBlank()) {
            _state.value = current.copy(nameError = true)
            return
        }
        if (current.isSaving || current.isLoading) return

        viewModelScope.launch {
            _state.value = current.copy(isSaving = true)
            val customer = Customer(
                id = current.id,
                name = current.name.trim(),
                phone = current.phone.trim(),
                instagramId = current.instagramId.trim().removePrefix("@"),
                address = current.address.trim(),
                note = current.note.trim(),
                createdDate = current.createdDate
            )
            runCatching {
                if (current.id == 0L) repository.add(customer) else repository.update(customer)
            }.onSuccess {
                _events.send(CustomerFormEvent.Saved)
            }.onFailure {
                _state.value = _state.value.copy(isSaving = false)
                _events.send(CustomerFormEvent.SaveFailed)
            }
        }
    }
}
