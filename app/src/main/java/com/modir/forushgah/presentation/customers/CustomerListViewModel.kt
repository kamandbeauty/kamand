package com.modir.forushgah.presentation.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.domain.model.Customer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class CustomerListUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val customers: List<Customer> = emptyList(),
) {
    val isEmpty: Boolean get() = !isLoading && customers.isEmpty() && query.isBlank()
}

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class CustomerListViewModel @Inject constructor(
    private val customerRepository: CustomerRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")

    private val customers = query.flatMapLatest { q ->
        if (q.isNotBlank()) customerRepository.observeSearch(q) else customerRepository.observeAll()
    }

    val uiState: StateFlow<CustomerListUiState> = combine(query, customers) { q, list ->
        CustomerListUiState(isLoading = false, query = q, customers = list)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CustomerListUiState())

    fun onQueryChange(value: String) {
        query.value = value
    }
}
