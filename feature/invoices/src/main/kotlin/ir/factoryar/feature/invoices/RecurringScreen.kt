package ir.factoryar.feature.invoices

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.RecurrenceInterval
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.JalaliDatePickerDialog

@Composable
fun RecurringScreen(
    onBack: (() -> Unit)? = null,
    viewModel: RecurringViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showEditor by remember { mutableStateOf(false) }

    Scaffold(
        topBar = { FyTopBar(title = "فاکتورهای دوره‌ای", onBack = onBack) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showEditor = true },
                icon = { Icon(Icons.Filled.Add, null) },
                text = { Text("قالب دوره‌ای جدید") },
            )
        },
    ) { padding ->
        when {
            state.items.isEmpty() -> EmptyState(
                icon = Icons.Filled.Repeat,
                title = "فاکتور دوره‌ای ندارید",
                description = "برای فروش‌های ماهانه/هفتگی ثابت (مثل اجاره یا اشتراک) قالب بسازید تا سررسید، فاکتور خودکار صادر و یادآوری شود.",
                modifier = Modifier.padding(padding),
            )
            else -> LazyColumn(
                modifier = Modifier.padding(padding).fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.items, key = { it.id }) { rec ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(rec.title, style = MaterialTheme.typography.titleSmall)
                                Text(
                                    (rec.customerId?.let { state.customers[it]?.name } ?: "بدون مشتری") + " • " + rec.interval.faName,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Text(
                                    "سررسید بعدی: ${JalaliConverter.fromEpochMillis(rec.nextRunDate).format().toPersianDigits()}",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                            Switch(checked = rec.active, onCheckedChange = { viewModel.toggle(rec.id, it) })
                            IconButton(onClick = { viewModel.delete(rec.id) }) {
                                Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f))
                            }
                        }
                    }
                }
                item { Spacer(Modifier.height(70.dp)) }
            }
        }
    }

    if (showEditor) {
        RecurringEditorDialog(
            customers = state.customers.values.toList(),
            onDismiss = { showEditor = false },
            onSave = { title, cid, interval, start, items, note ->
                viewModel.save(title, cid, interval, start, items, note)
                showEditor = false
            },
        )
    }
}

@Composable
private fun RecurringEditorDialog(
    customers: List<ir.factoryar.core.domain.model.Customer>,
    onDismiss: () -> Unit,
    onSave: (String, Long?, RecurrenceInterval, Long, List<InvoiceItem>, String) -> Unit,
) {
    var title by remember { mutableStateOf("") }
    var interval by remember { mutableStateOf(RecurrenceInterval.MONTHLY) }
    var startDate by remember { mutableStateOf(RecurringViewModel.defaultStart()) }
    var showDatePicker by remember { mutableStateOf(false) }
    var customerIndex by remember { mutableStateOf(-1) }
    var itemTitle by remember { mutableStateOf("") }
    var itemPrice by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    var templateItems by remember { mutableStateOf(listOf<InvoiceItem>()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("قالب فاکتور دوره‌ای") },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                item {
                    OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("عنوان (مثلاً اجاره ماهانه)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                }
                item {
                    Text("نوع تکرار", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        RecurrenceInterval.entries.forEach { i ->
                            FilterChip(selected = interval == i, onClick = { interval = i }, label = { Text(i.faName) })
                        }
                    }
                }
                item {
                    OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                        Text("شروع: ${JalaliConverter.fromEpochMillis(startDate).format().toPersianDigits()}")
                    }
                }
                item {
                    Text("مشتری", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        TextButton(onClick = { customerIndex = -1 }) { Text("هیچکدام") }
                        customers.take(3).forEachIndexed { idx, c ->
                            FilterChip(selected = customerIndex == idx, onClick = { customerIndex = idx }, label = { Text(c.name.take(10)) })
                        }
                    }
                }
                item { Text("اقلام قالب", style = MaterialTheme.typography.labelMedium) }
                items(templateItems) { ti ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(ti.title, Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                        Text(PersianFormatter.formatMoney(ti.unitPrice), style = MaterialTheme.typography.labelSmall)
                        IconButton(onClick = { templateItems = templateItems - ti }) { Icon(Icons.Filled.Delete, null) }
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        OutlinedTextField(value = itemTitle, onValueChange = { itemTitle = it }, placeholder = { Text("نام آیتم") }, modifier = Modifier.weight(1.4f), singleLine = true)
                        OutlinedTextField(value = itemPrice, onValueChange = { itemPrice = it }, placeholder = { Text("مبلغ") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.weight(1f), singleLine = true)
                    }
                    TextButton(onClick = {
                        if (itemTitle.isNotBlank()) {
                            templateItems = templateItems + InvoiceItem(title = itemTitle.trim(), unitPrice = PersianFormatter.parseMoney(itemPrice))
                            itemTitle = ""; itemPrice = ""
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("+ افزودن آیتم قالب") }
                }
                item {
                    OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("یادداشت") }, modifier = Modifier.fillMaxWidth())
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(
                        title.ifBlank { "فاکتور ${interval.faName}" },
                        customers.getOrNull(customerIndex)?.id,
                        interval,
                        startDate,
                        templateItems,
                        note,
                    )
                },
                enabled = templateItems.isNotEmpty(),
            ) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )

    if (showDatePicker) {
        JalaliDatePickerDialog(
            initialMillis = startDate,
            onDismiss = { showDatePicker = false },
            onConfirm = { startDate = it; showDatePicker = false },
            title = "تاریخ شروع",
        )
    }
}
