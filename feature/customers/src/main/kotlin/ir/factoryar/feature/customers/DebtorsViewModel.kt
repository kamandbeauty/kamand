package ir.factoryar.feature.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.domain.model.DebtorsSummary
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.usecase.BuildReminderMessageUseCase
import ir.factoryar.core.domain.usecase.ObserveDebtorsUseCase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DebtorsUiState(
    val sort: DebtorSort = DebtorSort.AMOUNT,
    val onlyOverdue: Boolean = false,
    val summary: DebtorsSummary = DebtorsSummary(),
    val isLoading: Boolean = true,
)

private data class DebtorFilters(val sort: DebtorSort, val onlyOverdue: Boolean)

@HiltViewModel
class DebtorsViewModel @Inject constructor(
    observeDebtors: ObserveDebtorsUseCase,
    private val buildReminderMessage: BuildReminderMessageUseCase,
    private val settingsRepository: SettingsRepository,
) : ViewModel() {

    private val filters = MutableStateFlow(DebtorFilters(DebtorSort.AMOUNT, false))

    @OptIn(ExperimentalCoroutinesApi::class)
    val uiState: StateFlow<DebtorsUiState> = combine(
        filters,
        filters.flatMapLatest { f -> observeDebtors(f.sort, f.onlyOverdue) },
    ) { f, summary ->
        DebtorsUiState(
            sort = f.sort,
            onlyOverdue = f.onlyOverdue,
            summary = summary,
            isLoading = false,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DebtorsUiState())

    fun setSort(sort: DebtorSort) { filters.value = filters.value.copy(sort = sort) }
    fun toggleOnlyOverdue() { filters.value = filters.value.copy(onlyOverdue = !filters.value.onlyOverdue) }

    /** ساخت متن یادآوری آماده ارسال (پیامک/واتساپ/تلگرام) */
    fun buildReminder(entry: DebtorEntry, onReady: (String) -> Unit) {
        viewModelScope.launch {
            val unit = CurrencyUnit.fromName(settingsRepository.settings.first().currencyUnit)
            val text = buildReminderMessage(
                entry = entry,
                formatMoney = { PersianFormatter.formatMoneyWithUnit(it, unit) },
                formatDate = { JalaliConverter.fromEpochMillis(it).format().toPersianDigits() },
            )
            onReady(text)
        }
    }
}
