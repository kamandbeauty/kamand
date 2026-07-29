package ir.factoryar.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.domain.model.CustomerWithBalance
import ir.factoryar.core.domain.model.DashboardSummary
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.usecase.ObserveCustomersUseCase
import ir.factoryar.core.domain.usecase.ObserveDashboardSummaryUseCase
import ir.factoryar.core.domain.usecase.ObserveInvoicesUseCase
import ir.factoryar.core.domain.repository.BusinessRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class DashboardUiState(
    val businessName: String = "",
    val summary: DashboardSummary = DashboardSummary(),
    val recentInvoices: List<InvoiceWithDetails> = emptyList(),
    val topDebtors: List<CustomerWithBalance> = emptyList(),
    val isLoading: Boolean = true,
)

private data class CoreData(
    val summary: DashboardSummary,
    val recent: List<InvoiceWithDetails>,
    val debtors: List<CustomerWithBalance>,
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    observeSummary: ObserveDashboardSummaryUseCase,
    observeInvoices: ObserveInvoicesUseCase,
    observeCustomers: ObserveCustomersUseCase,
    businessRepository: BusinessRepository,
) : ViewModel() {

    private val core: kotlinx.coroutines.flow.Flow<CoreData> = combine(
        observeSummary(),
        observeInvoices(),
        observeCustomers().map { list ->
            list.filter { it.totalDebt > 0 }.sortedByDescending { it.totalDebt }.take(3)
        },
    ) { summary, invoices, debtors ->
        CoreData(summary, invoices.take(5), debtors)
    }

    val uiState: StateFlow<DashboardUiState> = combine(
        core,
        businessRepository.observeActiveProfile().map { it?.name ?: "" },
    ) { c, name ->
        DashboardUiState(
            businessName = name,
            summary = c.summary,
            recentInvoices = c.recent,
            topDebtors = c.debtors,
            isLoading = false,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DashboardUiState())
}
