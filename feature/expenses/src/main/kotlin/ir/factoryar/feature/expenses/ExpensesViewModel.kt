package ir.factoryar.feature.expenses

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ExpenseCategory
import ir.factoryar.core.domain.model.ExpenseWithCategory
import ir.factoryar.core.domain.model.ProfitReport
import ir.factoryar.core.domain.model.ReportRange
import ir.factoryar.core.domain.repository.ExpenseRepository
import ir.factoryar.core.domain.usecase.BuildProfitReportUseCase
import ir.factoryar.core.domain.usecase.DeleteExpenseUseCase
import ir.factoryar.core.domain.usecase.SaveExpenseUseCase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExpensesUiState(
    val range: ReportRange = ReportRange.THIS_MONTH,
    val from: Long = 0,
    val to: Long = 0,
    val query: String = "",
    val categoryId: Long? = null,
    val expenses: List<ExpenseWithCategory> = emptyList(),
    val categories: List<ExpenseCategory> = emptyList(),
    val total: Long = 0,
    val profit: ProfitReport? = null,
    val isLoading: Boolean = true,
)

private data class ExpenseFilters(
    val range: ReportRange,
    val from: Long,
    val to: Long,
    val query: String,
    val categoryId: Long?,
)

@HiltViewModel
class ExpensesViewModel @Inject constructor(
    private val repository: ExpenseRepository,
    private val saveExpenseUseCase: SaveExpenseUseCase,
    private val deleteExpenseUseCase: DeleteExpenseUseCase,
    private val buildProfitReport: BuildProfitReportUseCase,
) : ViewModel() {

    private val filters = MutableStateFlow(defaultFilters())
    private val profit = MutableStateFlow<ProfitReport?>(null)

    init {
        viewModelScope.launch { repository.ensureDefaultCategories() }
        refreshProfit()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private val expenses = filters.flatMapLatest { f ->
        repository.observeExpenses(f.from, f.to, f.categoryId, f.query)
    }

    val uiState: StateFlow<ExpensesUiState> = combine(
        filters,
        expenses,
        repository.observeCategories(),
        profit,
    ) { f, list, categories, profitReport ->
        ExpensesUiState(
            range = f.range,
            from = f.from,
            to = f.to,
            query = f.query,
            categoryId = f.categoryId,
            expenses = list,
            categories = categories,
            total = list.sumOf { it.expense.amount },
            profit = profitReport,
            isLoading = false,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ExpensesUiState())

    fun setRange(range: ReportRange) {
        val (from, to) = rangeBounds(range)
        filters.value = filters.value.copy(range = range, from = from, to = to)
        refreshProfit()
    }

    fun setCustomRange(from: Long, to: Long) {
        filters.value = filters.value.copy(range = ReportRange.CUSTOM, from = from, to = to)
        refreshProfit()
    }

    fun setQuery(q: String) { filters.value = filters.value.copy(query = q) }
    fun setCategory(id: Long?) { filters.value = filters.value.copy(categoryId = id) }

    private fun refreshProfit() {
        val f = filters.value
        viewModelScope.launch {
            profit.value = buildProfitReport(f.from, f.to)
        }
    }

    fun saveExpense(
        id: Long,
        title: String,
        amountText: String,
        categoryId: Long?,
        date: Long,
        note: String,
        onDone: () -> Unit = {},
    ) {
        viewModelScope.launch {
            runCatching {
                saveExpenseUseCase(
                    Expense(
                        id = id,
                        title = title.trim(),
                        amount = PersianFormatter.parseMoney(amountText),
                        categoryId = categoryId,
                        date = date,
                        note = note.trim(),
                    ),
                )
            }.onSuccess {
                refreshProfit()
                onDone()
            }
        }
    }

    fun deleteExpense(id: Long) {
        viewModelScope.launch {
            deleteExpenseUseCase(id)
            refreshProfit()
        }
    }

    fun addCategory(name: String) {
        viewModelScope.launch {
            if (name.isNotBlank()) repository.saveCategory(ExpenseCategory(name = name.trim()))
        }
    }

    fun deleteCategory(id: Long) {
        viewModelScope.launch { repository.deleteCategory(id) }
    }

    companion object {
        private fun defaultFilters(): ExpenseFilters {
            val (from, to) = rangeBounds(ReportRange.THIS_MONTH)
            return ExpenseFilters(ReportRange.THIS_MONTH, from, to, "", null)
        }

        /** محاسبه ابتدا و انتهای بازه بر مبنای تقویم شمسی */
        fun rangeBounds(range: ReportRange): Pair<Long, Long> {
            val today = JalaliConverter.today()
            val endOfToday = DateUtils.plusDays(DateUtils.startOfToday(), 1)
            return when (range) {
                ReportRange.THIS_WEEK -> {
                    val weekday = JalaliConverter.weekdayOf(today) // ۰ = شنبه
                    DateUtils.startOfDay(DateUtils.plusDays(DateUtils.now(), -weekday)) to endOfToday
                }
                ReportRange.THIS_MONTH ->
                    JalaliConverter.toEpochMillis(JalaliDate(today.year, today.month, 1)) to endOfToday
                ReportRange.LAST_MONTH -> {
                    val year = if (today.month == 1) today.year - 1 else today.year
                    val month = if (today.month == 1) 12 else today.month - 1
                    JalaliConverter.toEpochMillis(JalaliDate(year, month, 1)) to
                        JalaliConverter.toEpochMillis(JalaliDate(today.year, today.month, 1))
                }
                ReportRange.LAST_3_MONTHS -> {
                    var year = today.year
                    var month = today.month - 2
                    if (month <= 0) {
                        month += 12
                        year -= 1
                    }
                    JalaliConverter.toEpochMillis(JalaliDate(year, month, 1)) to endOfToday
                }
                ReportRange.THIS_YEAR ->
                    JalaliConverter.toEpochMillis(JalaliDate(today.year, 1, 1)) to endOfToday
                ReportRange.CUSTOM ->
                    JalaliConverter.toEpochMillis(JalaliDate(today.year, today.month, 1)) to endOfToday
            }
        }
    }
}
