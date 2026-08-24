package com.modir.forushgah.presentation.stock

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.designsystem.component.StockBadge
import com.modir.forushgah.core.designsystem.component.stockLevelOf
import com.modir.forushgah.presentation.common.ProductRow
import com.modir.forushgah.presentation.common.SearchField

@Composable
fun StockAdjustmentRoute(
    onBack: () -> Unit,
    viewModel: StockAdjustmentViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var newStock by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("") }

    LaunchedEffect(event) {
        when (val e = event) {
            StockAdjustmentEvent.Adjusted -> onBack()
            is StockAdjustmentEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    // Prefill the new stock with the current value when a product is picked.
    LaunchedEffect(state.selectedProduct?.id) {
        state.selectedProduct?.let { product ->
            if (newStock.isEmpty()) newStock = product.stockQuantity.toString()
        }
        if (state.selectedProduct == null) {
            newStock = ""
            reason = ""
        }
    }

    StockAdjustmentScreen(
        state = state,
        newStock = newStock,
        reason = reason,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onQueryChange = viewModel::onQueryChange,
        onProductSelected = { viewModel.onProductSelected(it) },
        onProductCleared = viewModel::onProductCleared,
        onNewStockChange = { newStock = it },
        onReasonChange = { reason = it },
        onConfirm = { parsed -> viewModel.confirm(parsed, reason.ifBlank { null }) },
    )
}

@Composable
fun StockAdjustmentScreen(
    state: StockAdjustmentUiState,
    newStock: String,
    reason: String,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onQueryChange: (String) -> Unit,
    onProductSelected: (Long) -> Unit,
    onProductCleared: () -> Unit,
    onNewStockChange: (String) -> Unit,
    onReasonChange: (String) -> Unit,
    onConfirm: (Int) -> Unit,
) {
    val product = state.selectedProduct

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("تنظیم موجودی") },
                navigationIcon = {
                    TextButton(onClick = if (product != null) onProductCleared else onBack) {
                        Text("بازگشت")
                    }
                },
            )
        },
    ) { padding ->
        when {
            state.isLoading -> androidx.compose.foundation.layout.Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
            product == null -> Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                SearchField(
                    query = state.query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی محصول",
                )
                Text(
                    "محصول را انتخاب کنید",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(state.products, key = { it.id }) { p ->
                        ProductRow(product = p, onClick = { onProductSelected(p.id) })
                        Divider()
                    }
                }
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(product.name, style = MaterialTheme.typography.titleMedium, maxLines = 1)
                                    Text(
                                        "موجودی فعلی: ${PersianNumberFormatter.toPersianDigits(product.stockQuantity.toString())}",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                StockBadge(
                                    level = stockLevelOf(product.stockQuantity, product.minimumStock),
                                    alwaysShow = true,
                                )
                            }
                            TextButton(onClick = onProductCleared) { Text("تغییر محصول") }
                        }
                    }
                }
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedTextField(
                                value = newStock,
                                onValueChange = { onNewStockChange(it.filter { c -> c.isDigit() }) },
                                label = { Text("موجودی جدید") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            )
                            OutlinedTextField(
                                value = reason,
                                onValueChange = onReasonChange,
                                label = { Text("دلیل (اختیاری)") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            val parsed = newStock.toIntOrNull()
                            val delta = parsed?.minus(product.stockQuantity)
                            val deltaText = when {
                                delta == null -> "موجودی جدید را وارد کنید"
                                delta == 0 -> "بدون تغییر"
                                delta > 0 -> "افزایش ${PersianNumberFormatter.toPersianDigits(delta.toString())} واحد"
                                else -> "کاهش ${PersianNumberFormatter.toPersianDigits((-delta).toString())} واحد"
                            }
                            Text(
                                text = deltaText,
                                style = MaterialTheme.typography.bodyMedium,
                                color = when {
                                    delta == null || delta == 0 -> MaterialTheme.colorScheme.onSurfaceVariant
                                    delta > 0 -> MaterialTheme.colorScheme.primary
                                    else -> MaterialTheme.colorScheme.error
                                },
                            )
                            Button(
                                onClick = { parsed?.let(onConfirm) },
                                enabled = parsed != null,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text("ثبت تنظیم موجودی")
                            }
                        }
                    }
                }
            }
        }
    }
}
