package com.modir.forushgah.presentation.expenses

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.domain.model.ExpenseCategory

@Composable
fun ExpenseFormRoute(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: ExpenseFormViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.isSaved) {
        if (state.isSaved) onSaved()
    }

    LaunchedEffect(event) {
        when (val e = event) {
            is ExpenseFormEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    ExpenseFormScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onAmountChange = { value -> viewModel.onAmountChange(value.filter { c -> c.isDigit() }) },
        onCategoryChange = viewModel::onCategoryChange,
        onDateChange = { value -> viewModel.onDateChange(value.filter { c -> c.isDigit() || c == '/' }) },
        onDescriptionChange = viewModel::onDescriptionChange,
        onSave = viewModel::save,
    )
}

/**
 * Phase 4.2: add/edit expense form — مبلغ / دسته‌بندی / تاریخ (جلالی) /
 * توضیحات. Works in both modes (create with no id, edit with an id in the
 * route); in edit mode the financial effect is reversed and re-written by
 * the repository.
 */
@Composable
fun ExpenseFormScreen(
    state: ExpenseFormUiState,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onAmountChange: (String) -> Unit,
    onCategoryChange: (Long) -> Unit,
    onDateChange: (String) -> Unit,
    onDescriptionChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text(if (state.isEditMode) "ویرایش هزینه" else "ثبت هزینه") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
            )
        },
    ) { padding ->
        when {
            state.isLoading -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedTextField(
                                value = state.amountText,
                                onValueChange = onAmountChange,
                                label = { Text("مبلغ (تومان)") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                isError = state.errors.isNotEmpty() && state.amount == null,
                            )
                            state.amount?.let { amount ->
                                Text(
                                    text = amount.toPersianDisplayString(),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                            CategorySelector(
                                categories = state.categories,
                                selectedId = state.categoryId,
                                onSelected = onCategoryChange,
                            )
                            OutlinedTextField(
                                value = state.dateText,
                                onValueChange = onDateChange,
                                label = { Text("تاریخ") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            OutlinedTextField(
                                value = state.description,
                                onValueChange = onDescriptionChange,
                                label = { Text("توضیحات (اختیاری)") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }

                if (state.errors.isNotEmpty()) {
                    item {
                        Column {
                            state.errors.forEach { message ->
                                Text(
                                    text = message,
                                    color = MaterialTheme.colorScheme.error,
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                            }
                        }
                    }
                }

                item {
                    Button(
                        onClick = onSave,
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !state.isSaving,
                    ) {
                        Text(if (state.isEditMode) "ذخیره تغییرات" else "ثبت هزینه")
                    }
                }
            }
        }
    }
}

@Composable
private fun CategorySelector(
    categories: List<ExpenseCategory>,
    selectedId: Long?,
    onSelected: (Long) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selected = categories.firstOrNull { it.id == selectedId }
    Box {
        OutlinedTextField(
            value = selected?.name ?: "",
            onValueChange = {},
            readOnly = true,
            label = { Text("دسته‌بندی") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            trailingIcon = {
                IconButton(onClick = { expanded = true }) {
                    Icon(Icons.Filled.ArrowDropDown, contentDescription = "انتخاب دسته‌بندی")
                }
            },
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            categories.forEach { category ->
                DropdownMenuItem(
                    text = { Text(category.name) },
                    onClick = {
                        expanded = false
                        onSelected(category.id)
                    },
                )
            }
        }
    }
}
