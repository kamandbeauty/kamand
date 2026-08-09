package com.forushyar.app.ui.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.repository.CustomerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn

/** وضعیت و جست‌وجوی فهرست مشتری‌ها. */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class CustomersViewModel @Inject constructor(
    repository: CustomerRepository
) : ViewModel() {

    val query = MutableStateFlow("")

    val customers: StateFlow<List<Customer>> = query
        .flatMapLatest { value ->
            if (value.isBlank()) repository.observeAll() else repository.search(value.trim())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun onQueryChange(value: String) {
        query.value = value
    }
}
