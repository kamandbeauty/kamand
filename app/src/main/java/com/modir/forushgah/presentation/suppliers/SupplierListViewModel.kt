package com.modir.forushgah.presentation.suppliers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.SupplierRepository
import com.modir.forushgah.domain.model.Supplier
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class SupplierListUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val suppliers: List<Supplier> = emptyList(),
) {
    val isEmpty: Boolean get() = !isLoading && suppliers.isEmpty() && query.isBlank()
}

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class SupplierListViewModel @Inject constructor(
    private val supplierRepository: SupplierRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")

    private val suppliers = query.flatMapLatest { q ->
        if (q.isNotBlank()) supplierRepository.observeSearch(q) else supplierRepository.observeAll()
    }

    val uiState: StateFlow<SupplierListUiState> = combine(query, suppliers) { q, list ->
        SupplierListUiState(isLoading = false, query = q, suppliers = list)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SupplierListUiState())

    fun onQueryChange(value: String) {
        query.value = value
    }
}
