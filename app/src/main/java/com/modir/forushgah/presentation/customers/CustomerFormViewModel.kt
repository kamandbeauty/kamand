package com.modir.forushgah.presentation.customers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.domain.usecase.customer.CustomerDraft
import com.modir.forushgah.domain.usecase.customer.ValidateCustomerUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CustomerFormState(
    val customerId: Long? = null,
    val name: String = "",
    val mobile: String = "",
    val city: String = "",
    val address: String = "",
    val notes: String = "",
    val createdAt: Long = 0,
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
) {
    val isEditMode: Boolean get() = customerId != null
}

@HiltViewModel
class CustomerFormViewModel @Inject constructor(
    private val customerRepository: CustomerRepository,
    private val validateCustomer: ValidateCustomerUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _state = MutableStateFlow(
        CustomerFormState(customerId = savedStateHandle.get<Long>("customerId")),
    )
    val state: StateFlow<CustomerFormState> = _state.asStateFlow()

    init {
        _state.value.customerId?.let { id ->
            viewModelScope.launch {
                customerRepository.getById(id)?.let { customer ->
                    _state.update { it.fromCustomer(customer) }
                }
            }
        }
    }

    fun onNameChange(v: String) = _state.update { it.copy(name = v) }

    fun onMobileChange(v: String) = _state.update { it.copy(mobile = v.filter { c -> c.isDigit() || c == '+' }) }

    fun onCityChange(v: String) = _state.update { it.copy(city = v) }
    fun onAddressChange(v: String) = _state.update { it.copy(address = v) }
    fun onNotesChange(v: String) = _state.update { it.copy(notes = v) }

    fun save() {
        val s = _state.value
        val draft = CustomerDraft(
            name = s.name.trim(),
            mobile = s.mobile.ifBlank { null },
            address = s.address.ifBlank { null },
            city = s.city.ifBlank { null },
            notes = s.notes.ifBlank { null },
        )
        val result = validateCustomer(draft)
        if (result is ValidationResult.Invalid) {
            _state.update { it.copy(errors = result.messages) }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, errors = emptyList()) }
            val now = System.currentTimeMillis()
            val base = Customer(
                name = draft.name,
                mobile = draft.mobile,
                address = draft.address,
                city = draft.city,
                notes = draft.notes,
                createdAt = now,
                updatedAt = now,
            )
            if (s.isEditMode) {
                customerRepository.update(
                    base.copy(id = s.customerId!!, createdAt = s.createdAt, updatedAt = now),
                )
            } else {
                customerRepository.create(base.copy(createdAt = now, updatedAt = now))
            }
            _state.update { it.copy(isSaving = false, isSaved = true) }
        }
    }
}

private fun CustomerFormState.fromCustomer(c: Customer) = copy(
    name = c.name,
    mobile = c.mobile.orEmpty(),
    city = c.city.orEmpty(),
    address = c.address.orEmpty(),
    notes = c.notes.orEmpty(),
    createdAt = c.createdAt,
)
