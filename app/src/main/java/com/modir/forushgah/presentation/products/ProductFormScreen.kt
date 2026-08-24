package com.modir.forushgah.presentation.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@Composable
fun ProductFormRoute(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: ProductFormViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(state.isSaved) {
        if (state.isSaved) onSaved()
    }

    ProductFormScreen(
        state = state,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onSkuChange = viewModel::onSkuChange,
        onBarcodeChange = viewModel::onBarcodeChange,
        onCategoryChange = viewModel::onCategoryChange,
        onSupplierChange = viewModel::onSupplierChange,
        onSellingPriceChange = viewModel::onSellingPriceChange,
        onPurchasePriceChange = viewModel::onPurchasePriceChange,
        onPackagingCostChange = viewModel::onPackagingCostChange,
        onStockChange = viewModel::onStockChange,
        onMinimumStockChange = viewModel::onMinimumStockChange,
        onNotesChange = viewModel::onNotesChange,
        onSave = viewModel::save,
    )
}

@Composable
fun ProductFormScreen(
    state: ProductFormState,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onSkuChange: (String) -> Unit,
    onBarcodeChange: (String) -> Unit,
    onCategoryChange: (Long?) -> Unit,
    onSupplierChange: (Long?) -> Unit,
    onSellingPriceChange: (String) -> Unit,
    onPurchasePriceChange: (String) -> Unit,
    onPackagingCostChange: (String) -> Unit,
    onStockChange: (String) -> Unit,
    onMinimumStockChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (state.isEditMode) "ویرایش محصول" else "افزودن محصول") },
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
                    value = state.name, onValueChange = onNameChange,
                    label = { Text("نام محصول") }, modifier = Modifier.fillMaxWidth(), isError = state.errors.isNotEmpty(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.sku, onValueChange = onSkuChange,
                    label = { Text("کد محصول (SKU)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.barcode, onValueChange = onBarcodeChange,
                    label = { Text("بارکد (اختیاری)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            if (state.categories.isNotEmpty()) {
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(state.categories) { category ->
                            FilterChip(
                                selected = state.categoryId == category.id,
                                onClick = { onCategoryChange(if (state.categoryId == category.id) null else category.id) },
                                label = { Text(category.name) },
                            )
                        }
                    }
                }
            }
            if (state.suppliers.isNotEmpty()) {
                item {
                    Text("تأمین‌کننده (اختیاری)", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        item {
                            FilterChip(
                                selected = state.supplierId == null,
                                onClick = { onSupplierChange(null) },
                                label = { Text("بدون تأمین‌کننده") },
                            )
                        }
                        items(state.suppliers) { supplier ->
                            FilterChip(
                                selected = state.supplierId == supplier.id,
                                onClick = { onSupplierChange(if (state.supplierId == supplier.id) null else supplier.id) },
                                label = { Text(supplier.name) },
                            )
                        }
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = state.sellingPrice, onValueChange = onSellingPriceChange,
                    label = { Text("قیمت فروش (تومان)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.purchasePrice, onValueChange = onPurchasePriceChange,
                    label = { Text("قیمت خرید (تومان)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.packagingCost, onValueChange = onPackagingCostChange,
                    label = { Text("هزینه بسته‌بندی (تومان)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text("سود تخمینی هر واحد", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            state.estimatedProfitPreview.toPersianDisplayString(),
                            style = MaterialTheme.typography.titleLarge,
                        )
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = state.stockQuantity, onValueChange = onStockChange,
                    label = { Text("موجودی اولیه") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.minimumStock, onValueChange = onMinimumStockChange,
                    label = { Text("حداقل موجودی هشدار") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = state.notes, onValueChange = onNotesChange,
                    label = { Text("یادداشت (اختیاری)") }, modifier = Modifier.fillMaxWidth(),
                )
            }
            if (state.errors.isNotEmpty()) {
                item {
                    Column {
                        state.errors.forEach { message ->
                            Text(text = message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
            item {
                Button(onClick = onSave, modifier = Modifier.fillMaxWidth(), enabled = !state.isSaving) {
                    Text(if (state.isEditMode) "ذخیره تغییرات" else "افزودن محصول")
                }
            }
        }
    }
}
