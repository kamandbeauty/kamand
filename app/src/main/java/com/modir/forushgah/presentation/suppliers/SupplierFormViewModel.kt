package com.modir.forushgah.presentation.suppliers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.SupplierRepository
import com.modir.forushgah.domain.model.Supplier
import com.modir.forushgah.domain.usecase.supplier.SupplierDraft
import com.modir.forushgah.domain.usecase.supplier.ValidateSupplierUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SupplierFormState(
    val supplierId: Long? = null,
    val name: String = "",
    val phone: String = "",
    val address: String = "",
    val notes: String = "",
    val createdAt: Long = 0,
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
) {
    val isEditMode: Boolean get() = supplierId != null
}

@HiltViewModel
class SupplierFormViewModel @Inject constructor(
    private val supplierRepository: SupplierRepository,
    private val validateSupplier: ValidateSupplierUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _state = MutableStateFlow(
        SupplierFormState(supplierId = savedStateHandle.get<Long>("supplierId")),
    )
    val state: StateFlow<SupplierFormState> = _state.asStateFlow()

    init {
        _state.value.supplierId?.let { id ->
            viewModelScope.launch {
                supplierRepository.getById(id)?.let { supplier ->
                    _state.update { it.fromSupplier(supplier) }
                }
            }
        }
    }

    fun onNameChange(v: String) = _state.update { it.copy(name = v) }

    fun onPhoneChange(v: String) = _state.update { it.copy(phone = v.filter { c -> c.isDigit() || c == '+' }) }

    fun onAddressChange(v: String) = _state.update { it.copy(address = v) }
    fun onNotesChange(v: String) = _state.update { it.copy(notes = v) }

    fun save() {
        val s = _state.value
        val draft = SupplierDraft(
            name = s.name.trim(),
            phone = s.phone.ifBlank { null },
            address = s.address.ifBlank { null },
            notes = s.notes.ifBlank { null },
        )
        val result = validateSupplier(draft)
        if (result is ValidationResult.Invalid) {
            _state.update { it.copy(errors = result.messages) }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, errors = emptyList()) }
            val now = System.currentTimeMillis()
            val base = Supplier(
                name = draft.name,
                phone = draft.phone,
                address = draft.address,
                notes = draft.notes,
            )
            if (s.isEditMode) {
                supplierRepository.update(
                    base.copy(id = s.supplierId!!, createdAt = s.createdAt, updatedAt = now),
                )
            } else {
                supplierRepository.create(base.copy(createdAt = now, updatedAt = now))
            }
            _state.update { it.copy(isSaving = false, isSaved = true) }
        }
    }
}

private fun SupplierFormState.fromSupplier(sp: Supplier) = copy(
    name = sp.name,
    phone = sp.phone.orEmpty(),
    address = sp.address.orEmpty(),
    notes = sp.notes.orEmpty(),
    createdAt = sp.createdAt,
)
