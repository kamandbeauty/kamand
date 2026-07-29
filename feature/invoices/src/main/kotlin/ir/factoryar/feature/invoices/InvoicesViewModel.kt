package ir.factoryar.feature.invoices

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.usecase.DeleteInvoiceUseCase
import ir.factoryar.core.domain.usecase.ObserveInvoicesUseCase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class InvoiceFilter(
    val type: InvoiceType? = null,
    val status: PaymentStatus? = null,
    val overdueOnly: Boolean = false,
)

data class InvoicesUiState(
    val query: String = "",
    val filter: InvoiceFilter = InvoiceFilter(),
    val invoices: List<InvoiceWithDetails> = emptyList(),
) {
    val isEmpty: Boolean get() = invoices.isEmpty()
}

@HiltViewModel
class InvoicesViewModel @Inject constructor(
    private val observeInvoices: ObserveInvoicesUseCase,
    private val deleteInvoice: DeleteInvoiceUseCase,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val filter = MutableStateFlow(InvoiceFilter())

    @OptIn(ExperimentalCoroutinesApi::class)
    val uiState: StateFlow<InvoicesUiState> = combine(
        query, filter,
        combine(filter, query) { f, q -> observeInvoices(f.type, f.status, q, f.overdueOnly) }.flatMapLatest { it },
    ) { q, f, list ->
        InvoicesUiState(query = q, filter = f, invoices = list)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InvoicesUiState())

    fun onQueryChange(value: String) {
        query.value = value
    }

    fun setType(type: InvoiceType?) {
        filter.value = filter.value.copy(type = type)
    }

    fun setStatus(status: PaymentStatus?) {
        filter.value = filter.value.copy(status = status, overdueOnly = false)
    }

    fun setOverdueOnly() {
        filter.value = filter.value.copy(status = null, overdueOnly = true)
    }

    fun delete(id: Long) {
        viewModelScope.launch { deleteInvoice(id) }
    }
}
