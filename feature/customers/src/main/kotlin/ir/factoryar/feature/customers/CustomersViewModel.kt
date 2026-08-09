package ir.factoryar.feature.customers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.CustomerLedger
import ir.factoryar.core.domain.model.CustomerWithBalance
import ir.factoryar.core.domain.usecase.DeleteCustomerUseCase
import ir.factoryar.core.domain.usecase.GetCustomerLedgerUseCase
import ir.factoryar.core.domain.usecase.ObserveCustomersUseCase
import ir.factoryar.core.domain.usecase.SaveCustomerUseCase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CustomersUiState(
    val query: String = "",
    val customers: List<CustomerWithBalance> = emptyList(),
) {
    val isEmpty: Boolean get() = customers.isEmpty()
}

@HiltViewModel
class CustomersViewModel @Inject constructor(
    observeCustomers: ObserveCustomersUseCase,
    private val saveCustomer: SaveCustomerUseCase,
    private val deleteCustomer: DeleteCustomerUseCase,
) : ViewModel() {

    private val query = MutableStateFlow("")

    @OptIn(ExperimentalCoroutinesApi::class)
    val uiState: StateFlow<CustomersUiState> = combine(
        query,
        query.flatMapLatest { q -> observeCustomers(q) },
    ) { q, list -> CustomersUiState(query = q, customers = list) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CustomersUiState())

    fun onQueryChange(value: String) {
        query.value = value
    }

    fun save(customer: Customer, onSaved: (Long) -> Unit = {}) {
        viewModelScope.launch {
            runCatching { saveCustomer(customer) }.onSuccess(onSaved)
        }
    }

    fun delete(id: Long) {
        viewModelScope.launch { deleteCustomer(id) }
    }
}

data class CustomerDetailUiState(
    val ledger: CustomerLedger? = null,
    val loading: Boolean = true,
)

@HiltViewModel
class CustomerDetailViewModel @Inject constructor(
    getCustomerLedger: GetCustomerLedgerUseCase,
    private val deleteCustomer: DeleteCustomerUseCase,
    private val saveCustomer: SaveCustomerUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val customerId: Long = savedStateHandle.get<Long>("customerId") ?: 0L

    val uiState: StateFlow<CustomerDetailUiState> = getCustomerLedger(customerId)
        .map { CustomerDetailUiState(ledger = it, loading = false) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CustomerDetailUiState())

    fun save(customer: Customer) {
        viewModelScope.launch { saveCustomer(customer.copy(id = customerId)) }
    }

    fun delete(onDeleted: () -> Unit = {}) {
        viewModelScope.launch {
            deleteCustomer(customerId)
            onDeleted()
        }
    }
}
