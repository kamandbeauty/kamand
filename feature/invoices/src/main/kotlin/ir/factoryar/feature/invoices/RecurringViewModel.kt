package ir.factoryar.feature.invoices

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.RecurrenceInterval
import ir.factoryar.core.domain.model.RecurringInvoice
import ir.factoryar.core.domain.model.RecurringTemplate
import ir.factoryar.core.domain.repository.CustomerRepository
import ir.factoryar.core.domain.repository.RecurringRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RecurringUiState(
    val items: List<RecurringInvoice> = emptyList(),
    val customers: Map<Long, Customer> = emptyMap(),
)

@HiltViewModel
class RecurringViewModel @Inject constructor(
    private val recurringRepository: RecurringRepository,
    customerRepository: CustomerRepository,
) : ViewModel() {

    val uiState: StateFlow<RecurringUiState> = combine(
        recurringRepository.observeAll(),
        customerRepository.observeCustomers(),
    ) { recurring, customers ->
        RecurringUiState(
            items = recurring,
            customers = customers.associate { it.customer.id to it.customer },
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), RecurringUiState())

    fun save(
        title: String,
        customerId: Long?,
        interval: RecurrenceInterval,
        startDate: Long,
        templateItems: List<InvoiceItem>,
        note: String,
    ) {
        viewModelScope.launch {
            recurringRepository.save(
                RecurringInvoice(
                    title = title,
                    customerId = customerId,
                    interval = interval,
                    startDate = startDate,
                    nextRunDate = startDate,
                    active = true,
                    template = RecurringTemplate(items = templateItems, note = note),
                ),
            )
        }
    }

    fun toggle(id: Long, active: Boolean) {
        viewModelScope.launch { recurringRepository.setActive(id, active) }
    }

    fun delete(id: Long) {
        viewModelScope.launch { recurringRepository.delete(id) }
    }

    companion object {
        fun defaultStart(): Long = DateUtils.plusDays(DateUtils.startOfToday(), 1)
    }
}
