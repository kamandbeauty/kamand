package com.modir.forushgah.presentation.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@Composable
fun CustomerFormRoute(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: CustomerFormViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(state.isSaved) {
        if (state.isSaved) onSaved()
    }

    CustomerFormScreen(
        state = state,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onMobileChange = viewModel::onMobileChange,
        onCityChange = viewModel::onCityChange,
        onAddressChange = viewModel::onAddressChange,
        onNotesChange = viewModel::onNotesChange,
        onSave = viewModel::save,
    )
}

@Composable
fun CustomerFormScreen(
    state: CustomerFormState,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onMobileChange: (String) -> Unit,
    onCityChange: (String) -> Unit,
    onAddressChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (state.isEditMode) "ویرایش مشتری" else "افزودن مشتری") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                OutlinedTextField(
                    value = state.name,
                    onValueChange = onNameChange,
                    label = { Text("نام مشتری") },
                    modifier = Modifier.fillMaxWidth(),
                    isError = state.errors.isNotEmpty(),
                    singleLine = true,
                )
            }
            item {
                OutlinedTextField(
                    value = state.mobile,
                    onValueChange = onMobileChange,
                    label = { Text("موبایل (اختیاری)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                )
            }
            item {
                OutlinedTextField(
                    value = state.city,
                    onValueChange = onCityChange,
                    label = { Text("شهر (اختیاری)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
            }
            item {
                OutlinedTextField(
                    value = state.address,
                    onValueChange = onAddressChange,
                    label = { Text("آدرس (اختیاری)") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.notes,
                    onValueChange = onNotesChange,
                    label = { Text("یادداشت (اختیاری)") },
                    modifier = Modifier.fillMaxWidth(),
                )
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
                Button(onClick = onSave, modifier = Modifier.fillMaxWidth(), enabled = !state.isSaving) {
                    Text(if (state.isEditMode) "ذخیره تغییرات" else "افزودن مشتری")
                }
            }
        }
    }
}
