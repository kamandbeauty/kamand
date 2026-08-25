package com.modir.forushgah.presentation.expenses

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.core.designsystem.component.StatCard
import com.modir.forushgah.data.local.dao.ExpenseWithCategory
import com.modir.forushgah.data.repository.ExpenseRepository
import com.modir.forushgah.core.common.Money
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExpenseListUiState(
    val isLoading: Boolean = true,
    val expenses: List<ExpenseWithCategory> = emptyList(),
    val total: Money = Money.ZERO,
)

sealed interface ExpenseListEvent {
    object ExpenseDeleted : ExpenseListEvent
    data class Error(val message: String) : ExpenseListEvent
}

@HiltViewModel
class ExpenseListViewModel @Inject constructor(
    private val expenseRepository: ExpenseRepository,
) : ViewModel() {

    val uiState: StateFlow<ExpenseListUiState> = combine(
        expenseRepository.observeExpenses(),
        expenseRepository.observeTotal(),
    ) { expenses, total ->
        ExpenseListUiState(isLoading = false, expenses = expenses, total = total)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ExpenseListUiState())

    private val _event = MutableStateFlow<ExpenseListEvent?>(null)
    val event: StateFlow<ExpenseListEvent?> = _event.asStateFlow()

    fun consumeEvent() {
        _event.value = null
    }

    /** Confirmed delete: soft delete + exactly-once financial reversal. */
    fun deleteExpense(id: Long) {
        viewModelScope.launch {
            try {
                expenseRepository.deleteExpense(id)
                _event.value = ExpenseListEvent.ExpenseDeleted
            } catch (e: Exception) {
                _event.value = ExpenseListEvent.Error(e.message ?: "حذف هزینه با خطا مواجه شد")
            }
        }
    }
}

@Composable
fun ExpenseListRoute(
    onAddClick: () -> Unit,
    onEditClick: (Long) -> Unit,
    viewModel: ExpenseListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var expenseToDelete by remember { mutableStateOf<ExpenseWithCategory?>(null) }

    LaunchedEffect(event) {
        when (val e = event) {
            ExpenseListEvent.ExpenseDeleted ->
                snackbarHostState.showSnackbar("هزینه حذف شد و روال مالی آن اصلاح شد")
            is ExpenseListEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    ExpenseListScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        expenseToDelete = expenseToDelete,
        onAddClick = onAddClick,
        onEditClick = onEditClick,
        onDeleteClick = { expenseToDelete = it },
        onDeleteConfirmed = {
            expenseToDelete?.let { viewModel.deleteExpense(it.expense.id) }
            expenseToDelete = null
        },
        onDismissDelete = { expenseToDelete = null },
    )
}

/**
 * Phase 4.2: expense list (the «مالی» tab). Active expenses with their
 * category, amount and Jalali date, plus the running total. Tapping a row
 * opens the edit form; deletion requires confirmation.
 */
@Composable
fun ExpenseListScreen(
    state: ExpenseListUiState,
    snackbarHostState: SnackbarHostState,
    expenseToDelete: ExpenseWithCategory?,
    onAddClick: () -> Unit,
    onEditClick: (Long) -> Unit,
    onDeleteClick: (ExpenseWithCategory) -> Unit,
    onDeleteConfirmed: () -> Unit,
    onDismissDelete: () -> Unit,
) {
    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = { TopAppBar(title = { Text("هزینه‌ها") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddClick) {
                Icon(Icons.Filled.Add, contentDescription = "ثبت هزینه")
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }

                state.expenses.isEmpty() -> EmptyState(
                    title = "هنوز هزینه‌ای ثبت نشده",
                    subtitle = "خریدهای نقدی مثل بسته‌بندی، اجاره و قبوض را این‌جا ثبت کنید",
                    ctaLabel = "ثبت اولین هزینه",
                    onCtaClick = onAddClick,
                    modifier = Modifier.align(Alignment.Center),
                )

                else -> LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item {
                        StatCard(
                            label = "جمع هزینه‌های ثبت‌شده",
                            value = state.total.toPersianDisplayString(),
                            emphasis = true,
                        )
                    }
                    items(state.expenses, key = { it.expense.id }) { row ->
                        ExpenseRow(
                            row = row,
                            onClick = { onEditClick(row.expense.id) },
                            onDelete = { onDeleteClick(row) },
                        )
                    }
                }
            }
        }
        if (expenseToDelete != null) {
            DeleteExpenseDialog(
                row = expenseToDelete!!,
                onConfirm = onDeleteConfirmed,
                onDismiss = onDismissDelete,
            )
        }
    }
}

@Composable
private fun ExpenseRow(
    row: ExpenseWithCategory,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val expense = row.expense
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            modifier = Modifier.padding(start = 16.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Surface(
                        shape = MaterialTheme.shapes.small,
                        color = MaterialTheme.colorScheme.secondaryContainer,
                    ) {
                        Text(
                            row.categoryName,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        )
                    }
                    Text(
                        JalaliDateFormatter.formatJalali(expense.date),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    expense.amount.toPersianDisplayString(),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                if (!expense.description.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        expense.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
            }
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Filled.DeleteOutline,
                    contentDescription = "حذف هزینه",
                    tint = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

@Composable
private fun DeleteExpenseDialog(
    row: ExpenseWithCategory,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("حذف هزینه") },
        text = {
            Text(
                "هزینه «${row.categoryName}» به مبلغ ${row.expense.amount.toPersianDisplayString()} " +
                    "حذف می‌شود. تاریخچه مالی حفظ می‌ماند و روال مالی آن اصلاح می‌شود.",
            )
        },
        confirmButton = { TextButton(onClick = onConfirm) { Text("حذف") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
