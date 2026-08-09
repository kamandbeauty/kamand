package ir.factoryar.feature.products

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import ir.factoryar.core.barcode.BarcodeScannerDialog
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.formatDateTime
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.SectionHeader

@Composable
fun ProductEditScreen(
    onBack: () -> Unit,
    onSaved: (Long) -> Unit,
    viewModel: ProductEditViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showScanner by remember { mutableStateOf(false) }
    var showCategoryDialog by remember { mutableStateOf(false) }
    var showStockDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            FyTopBar(
                title = if (state.productId > 0) "ویرایش کالا" else "کالای جدید",
                onBack = onBack,
            )
        },
        bottomBar = {
            Button(
                onClick = { viewModel.save(onSaved) },
                enabled = state.canSave,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .height(50.dp),
            ) { Text("ذخیره کالا") }
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = state.name,
                        onValueChange = viewModel::setName,
                        label = { Text("نام کالا یا خدمات *") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = state.barcode,
                            onValueChange = viewModel::setBarcode,
                            label = { Text("بارکد") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = { showScanner = true }) {
                            Icon(Icons.Filled.QrCodeScanner, contentDescription = "اسکن بارکد")
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = state.sku,
                            onValueChange = viewModel::setSku,
                            label = { Text("کد کالا") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.unit,
                            onValueChange = viewModel::setUnit,
                            label = { Text("واحد") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }

            item {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("خدمات است (بدون موجودی)", style = MaterialTheme.typography.bodyMedium)
                        Text(
                            "برای خدمات، موجودی انبار کسر نمی‌شود",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(checked = state.isService, onCheckedChange = viewModel::setIsService)
                }
            }

            item { SectionHeader(title = "دسته‌بندی") }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(state.categories) { c ->
                        FilterChip(
                            selected = state.categoryId == c.id,
                            onClick = { viewModel.setCategory(if (state.categoryId == c.id) null else c.id) },
                            label = { Text(c.name, style = MaterialTheme.typography.labelMedium) },
                        )
                    }
                    item {
                        AssistChip(
                            onClick = { showCategoryDialog = true },
                            label = { Text("دسته جدید") },
                            leadingIcon = { Icon(Icons.Filled.Add, null) },
                        )
                    }
                }
            }

            item { SectionHeader(title = "قیمت‌گذاری") }
            item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = state.retailPrice,
                            onValueChange = viewModel::setRetailPrice,
                            label = { Text("قیمت خرده") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.wholesalePrice,
                            onValueChange = viewModel::setWholesalePrice,
                            label = { Text("قیمت عمده") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = state.costPrice,
                            onValueChange = viewModel::setCostPrice,
                            label = { Text("بهای تمام‌شده") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.taxPercent,
                            onValueChange = viewModel::setTaxPercent,
                            label = { Text("مالیات٪") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (state.unitProfit != 0L) {
                        Card(
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            ),
                        ) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    "سود هر واحد",
                                    Modifier.weight(1f),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                                MoneyText(
                                    state.unitProfit,
                                    style = MaterialTheme.typography.titleSmall,
                                    color = if (state.unitProfit >= 0) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.error
                                    },
                                )
                                Spacer(Modifier.width(8.dp))
                                Text(
                                    "(${PersianFormatter.formatQuantity(state.marginPercent)}٪)",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            if (!state.isService) {
                item { SectionHeader(title = "موجودی انبار") }
                item {
                    Row(
                        Modifier.padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        OutlinedTextField(
                            value = state.stockQuantity,
                            onValueChange = viewModel::setStockQuantity,
                            label = { Text(if (state.productId > 0) "موجودی فعلی" else "موجودی اولیه") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            singleLine = true,
                            enabled = state.productId == 0L,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.lowStockThreshold,
                            onValueChange = viewModel::setLowStockThreshold,
                            label = { Text("هشدار کمبود") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                if (state.productId > 0) {
                    item {
                        TextButton(
                            onClick = { showStockDialog = true },
                            modifier = Modifier.padding(horizontal = 16.dp),
                        ) { Text("اصلاح دستی موجودی") }
                    }
                }
            }

            item {
                OutlinedTextField(
                    value = state.note,
                    onValueChange = viewModel::setNote,
                    label = { Text("توضیحات") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                )
            }

            if (state.error != null) {
                item {
                    Text(
                        state.error!!,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
            }

            if (state.movements.isNotEmpty()) {
                item { SectionHeader(title = "کاردکس انبار") }
                items(state.movements, key = { it.id }) { m ->
                    Column(Modifier.padding(horizontal = 16.dp)) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                            Text(
                                m.reason.faName,
                                Modifier.weight(1f),
                                style = MaterialTheme.typography.bodySmall,
                            )
                            Text(
                                (if (m.quantityDelta > 0) "+" else "") +
                                    PersianFormatter.formatQuantity(m.quantityDelta),
                                style = MaterialTheme.typography.bodySmall,
                                color = if (m.quantityDelta > 0) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.error
                                },
                            )
                            Spacer(Modifier.width(10.dp))
                            Text(
                                formatDateTime(m.createdAt),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }

    if (showScanner) {
        BarcodeScannerDialog(
            onDismiss = { showScanner = false },
            onBarcode = { code ->
                viewModel.setBarcode(code)
                showScanner = false
            },
        )
    }

    if (showCategoryDialog) {
        var name by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showCategoryDialog = false },
            title = { Text("دسته‌بندی جدید") },
            text = {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("نام دسته") },
                    singleLine = true,
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.addCategory(name)
                        showCategoryDialog = false
                    },
                    enabled = name.isNotBlank(),
                ) { Text("افزودن") }
            },
            dismissButton = { TextButton(onClick = { showCategoryDialog = false }) { Text("انصراف") } },
        )
    }

    if (showStockDialog) {
        var amount by remember { mutableStateOf("") }
        var note by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showStockDialog = false },
            title = { Text("اصلاح موجودی") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "برای افزایش، عدد مثبت و برای کاهش، عدد منفی وارد کنید.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    OutlinedTextField(
                        value = amount,
                        onValueChange = { amount = it },
                        label = { Text("مقدار تغییر") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = note,
                        onValueChange = { note = it },
                        label = { Text("علت") },
                        singleLine = true,
                    )
                }
            },
            confirmButton = {
                Button(onClick = {
                    val delta = PersianFormatter.parseDouble(amount.replace("−", "-"))
                    viewModel.adjustStock(delta, note.ifBlank { "اصلاح دستی" })
                    showStockDialog = false
                }) { Text("ثبت") }
            },
            dismissButton = { TextButton(onClick = { showStockDialog = false }) { Text("انصراف") } },
        )
    }
}
