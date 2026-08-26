package com.modir.forushgah.presentation.expenses

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.data.repository.ExpenseRepository
import com.modir.forushgah.data.repository.NewExpense
import com.modir.forushgah.domain.model.ExpenseCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExpenseFormUiState(
    val expenseId: Long? = null,
    val isLoading: Boolean = true,
    val categories: List<ExpenseCategory> = emptyList(),
    val amountText: String = "",
    val categoryId: Long? = null,
    val dateText: String = JalaliDateFormatter.todayJalali(),
    val description: String = "",
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
) {
    val isEditMode: Boolean get() = expenseId != null

    /** Parsed amount in Toman (Persian or Latin digits); null when invalid. */
    val amount: Money?
        get() = amountText.toEnglishDigits().filter { it.isDigit() }
            .takeIf { it.isNotEmpty() }
            ?.toLongOrNull()
            ?.let { Money(it) }
}

sealed interface ExpenseFormEvent {
    data class Error(val message: String) : ExpenseFormEvent
}

/** Converts Persian digits to Latin so the amount parses as a Long. */
internal fun String.toEnglishDigits(): String =
    map { ch -> if (ch in '\u06F0'..'\u06F9') '0' + (ch - '\u06F0') else ch }.joinToString("")

@HiltViewModel
class ExpenseFormViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val expenseId: Long? = savedStateHandle.get<String>("expenseId")?.toLongOrNull()

    private val _state = MutableStateFlow(ExpenseFormUiState(expenseId = expenseId))
    val state: StateFlow<ExpenseFormUiState> = _state.asStateFlow()

    private val _event = MutableStateFlow<ExpenseFormEvent?>(null)
    val event: StateFlow<ExpenseFormEvent?> = _event.asStateFlow()

    fun consumeEvent() {
        _event.value = null
    }

    init {
        viewModelScope.launch {
            expenseRepository.observeCategories().first().let { categories ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        categories = categories,
                        categoryId = it.categoryId ?: categories.firstOrNull()?.id,
                    )
                }
            }
            val id = expenseId ?: return@launch
            val expense = expenseRepository.getExpense(id)
            if (expense == null) {
                _event.value = ExpenseFormEvent.Error("هزینه پیدا نشد")
                return@launch
            }
            _state.update {
                it.copy(
                    amountText = expense.amount.amountInToman.toString(),
                    categoryId = expense.categoryId,
                    dateText = JalaliDateFormatter.formatJalali(expense.date, persianDigits = false),
                    description = expense.description.orEmpty(),
                )
            }
        }
    }

    fun onAmountChange(value: String) = _state.update { it.copy(amountText = value) }

    fun onCategoryChange(categoryId: Long) = _state.update {
        it.copy(categoryId = categoryId, errors = emptyList())
    }

    fun onDateChange(value: String) = _state.update { it.copy(dateText = value) }

    fun onDescriptionChange(value: String) = _state.update { it.copy(description = value) }

    fun save() {
        val s = _state.value
        val amount = s.amount
        val categoryId = s.categoryId
        val date = JalaliDateFormatter.parseJalaliText(s.dateText)

        val errors = buildList {
            if (amount == null || !amount.isPositive) add("مبلغ را به تومان وارد کنید (بیشتر از صفر)")
            if (categoryId == null) add("دسته‌بندی را انتخاب کنید")
            if (date == null) add("تاریخ معتبر نیست — از الگوی 1403/06/02 استفاده کنید")
        }
        if (errors.isNotEmpty()) {
            _state.update { it.copy(errors = errors) }
            return
        }

        val draft = NewExpense(
            categoryId = categoryId!!,
            amount = amount!!,
            date = date!!,
            description = s.description.trim().takeIf { it.isNotEmpty() },
        )

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, errors = emptyList()) }
            try {
                if (s.isEditMode) {
                    expenseRepository.updateExpense(s.expenseId!!, draft)
                } else {
                    expenseRepository.createExpense(draft)
                }
                _state.update { it.copy(isSaving = false, isSaved = true) }
            } catch (e: Exception) {
                _state.update {
                    it.copy(isSaving = false, errors = listOf(e.message ?: "ثبت هزینه با خطا مواجه شد"))
                }
            }
        }
    }
}
