package ir.factoryar.feature.invoices

import android.content.Context
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Draw
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.formatMoney
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.JalaliDatePickerDialog
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.barcode.BarcodeScannerDialog
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.components.SignaturePad
import ir.factoryar.core.ui.components.rememberSignaturePadState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

@Composable
fun InvoiceEditScreen(
    onBack: () -> Unit,
    onSaved: (Long) -> Unit,
    viewModel: InvoiceEditViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var showIssuePicker by remember { mutableStateOf(false) }
    var showDuePicker by remember { mutableStateOf(false) }
    var showCustomerDialog by remember { mutableStateOf(false) }
    var showSignatureDialog by remember { mutableStateOf(false) }
    var showScanner by remember { mutableStateOf(false) }
    var showProductPicker by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.consumeMessage()
        }
    }

    val title = if (state.invoiceId > 0) "ویرایش ${state.type.faName}" else "صدور ${state.type.faName}"

    Scaffold(
        topBar = {
            FyTopBar(
                title = title,
                onBack = onBack,
                actions = {
                    if (state.isSaving) {
                        CircularProgressIndicator(modifier = Modifier.padding(12.dp).size(22.dp), strokeWidth = 2.dp)
                    } else {
                        TextButton(onClick = { viewModel.save(onSaved) }, enabled = state.items.any { it.title.isNotBlank() }) {
                            Text("ذخیره")
                        }
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(bottom = 32.dp),
        ) {
            // ۱) اطلاعات کلی
            item {
                Card(
                    Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
                ) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            if (state.invoiceId > 0) "شماره: ${state.number.toPersianDigits()}" else state.number,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { showIssuePicker = true }, modifier = Modifier.weight(1f)) {
                                Icon(Icons.Filled.DateRange, null, Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(JalaliConverter.fromEpochMillis(state.issueDate).format().toPersianDigits())
                            }
                            OutlinedButton(onClick = { showDuePicker = true }, modifier = Modifier.weight(1f)) {
                                Text(
                                    state.dueDate?.let { "سررسید: ${JalaliConverter.fromEpochMillis(it).format().toPersianDigits()}" } ?: "بدون سررسید +",
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                }
            }

            // ۲) مشتری
            item {
                Card(
                    Modifier.padding(horizontal = 16.dp, vertical = 6.dp).clickable { showCustomerDialog = true },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
                ) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Person, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text("مشتری", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                state.customerName.ifBlank { "انتخاب مشتری…" },
                                style = MaterialTheme.typography.titleSmall,
                                color = if (state.customerName.isBlank()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                            )
                        }
                        if (state.customerId != null) {
                            TextButton(onClick = { viewModel.selectCustomer(null) }) { Text("حذف") }
                        }
                    }
                }
            }

            // ۳) اقلام
            item {
                SectionHeader(title = "اقلام فاکتور") {
                    if (state.products.isNotEmpty()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "قیمت عمده",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Switch(
                                checked = state.useWholesalePrice,
                                onCheckedChange = viewModel::setUseWholesalePrice,
                            )
                        }
                    }
                }
            }
            // نوار افزودن سریع از انبار / اسکن بارکد
            item {
                Row(
                    Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedButton(onClick = { showScanner = true }, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Filled.QrCodeScanner, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("اسکن بارکد")
                    }
                    OutlinedButton(onClick = { showProductPicker = true }, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Filled.Inventory2, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("از انبار")
                    }
                }
            }
            items(state.items, key = { it.key }) { item ->
                ItemEditorCard(
                    item = item,
                    onChange = { transform -> viewModel.updateItem(item.key, transform) },
                    onRemove = { viewModel.removeItem(item.key) },
                    canRemove = state.items.size > 1,
                    showTaxDiscount = true,
                )
            }
            item {
                OutlinedButton(
                    onClick = viewModel::addItem,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth(),
                ) {
                    Icon(Icons.Filled.Add, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("افزودن آیتم")
                }
            }

            // ۴) جمع‌ها
            item {
                Card(
                    Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)),
                ) {
                    val totals = state.totals
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        TotalRow("جمع اقلام", totals.subtotal)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("تخفیف کلی", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                            OutlinedTextField(
                                value = state.globalDiscountText,
                                onValueChange = viewModel::setGlobalDiscount,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                singleLine = true,
                                modifier = Modifier.width(140.dp),
                                textStyle = MaterialTheme.typography.bodyMedium,
                            )
                        }
                        TotalRow("مالیات بر ارزش افزوده", totals.taxTotal)
                        HorizontalDivider()
                        Row {
                            Text("مبلغ قابل پرداخت", modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                            MoneyText(totals.grandTotal, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                        }
                        // سود تخمینی این فاکتور (وقتی بهای تمام‌شده ثبت شده باشد)
                        if (state.hasCostData && state.type == InvoiceType.SALE) {
                            HorizontalDivider()
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    "سود ناخالص تخمینی",
                                    modifier = Modifier.weight(1f),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                MoneyText(
                                    state.estimatedProfit,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = if (state.estimatedProfit >= 0) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.error
                                    },
                                )
                            }
                        }
                        if (state.hasStockWarning) {
                            Text(
                                "توجه: مقدار برخی اقلام از موجودی انبار بیشتر است؛ موجودی منفی خواهد شد.",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }

            // ۵) وضعیت پرداخت
            item {
                SectionHeader(title = "وضعیت پرداخت")
                Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PaymentStatus.entries.forEach { s ->
                        FilterChip(
                            selected = state.status == s,
                            onClick = { viewModel.setStatus(s) },
                            label = { Text(s.faName) },
                        )
                    }
                }
                if (state.status == PaymentStatus.PARTIAL) {
                    OutlinedTextField(
                        value = state.paidAmountText,
                        onValueChange = viewModel::setPaidAmount,
                        label = { Text("مبلغ پرداخت‌شده") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth(),
                    )
                    val remaining = state.totals.grandTotal - PersianFormatter.parseMoney(state.paidAmountText)
                    Text(
                        "مانده: ${formatMoney(remaining.coerceAtLeast(0))}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(horizontal = 24.dp),
                    )
                }
            }

            // ۶) یادداشت و شرایط
            item {
                SectionHeader(title = "یادداشت و شرایط")
                OutlinedTextField(
                    value = state.note,
                    onValueChange = viewModel::setNote,
                    label = { Text("یادداشت روی فاکتور") },
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth(),
                )
                OutlinedTextField(
                    value = state.terms,
                    onValueChange = viewModel::setTerms,
                    label = { Text("شرایط و ضوابط (مثلاً مدت اعتبار)") },
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth(),
                )
            }

            // ۷) امضای دیجیتال
            item {
                SectionHeader(title = "امضای دیجیتال")
                Row(
                    Modifier.padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedButton(onClick = { showSignatureDialog = true }) {
                        Icon(Icons.Filled.Draw, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(if (state.signaturePath == null) "افزودن امضا" else "ویرایش امضا")
                    }
                    if (state.signaturePath != null) {
                        Spacer(Modifier.width(10.dp))
                        AssistChip(onClick = { viewModel.setSignaturePath(null) }, label = { Text("حذف امضا") })
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }

    if (showIssuePicker) {
        JalaliDatePickerDialog(
            initialMillis = state.issueDate,
            onDismiss = { showIssuePicker = false },
            onConfirm = { viewModel.setIssueDate(it); showIssuePicker = false },
            title = "تاریخ صدور",
        )
    }
    if (showDuePicker) {
        JalaliDatePickerDialog(
            initialMillis = state.dueDate ?: state.issueDate,
            onDismiss = { showDuePicker = false },
            onConfirm = { viewModel.setDueDate(it); showDuePicker = false },
            title = "تاریخ سررسید",
        )
    }
    if (showCustomerDialog) {
        CustomerPickerDialog(
            customers = state.customers,
            onDismiss = { showCustomerDialog = false },
            onSelect = { viewModel.selectCustomer(it); showCustomerDialog = false },
            onQuickCreate = { name, phone -> viewModel.quickCreateCustomer(name, phone) { showCustomerDialog = false } },
        )
    }
    if (showScanner) {
        BarcodeScannerDialog(
            onDismiss = { showScanner = false },
            onBarcode = { code ->
                viewModel.onBarcodeScanned(code)
                showScanner = false
            },
            title = "اسکن بارکد برای افزودن به فاکتور",
        )
    }
    if (showProductPicker) {
        ProductPickerDialog(
            products = state.products,
            useWholesale = state.useWholesalePrice,
            onDismiss = { showProductPicker = false },
            onSelect = { product ->
                viewModel.addProduct(product)
                showProductPicker = false
            },
        )
    }
    if (showSignatureDialog) {
        SignatureEntryDialog(
            onDismiss = { showSignatureDialog = false },
            onSave = { bitmap ->
                scope.launch {
                    val path = saveSignature(context, bitmap, state.invoiceId)
                    viewModel.setSignaturePath(path)
                    showSignatureDialog = false
                }
            },
        )
    }
}

@Composable
private fun TotalRow(label: String, amount: Long) {
    Row {
        Text(label, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        MoneyText(amount, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun ItemEditorCard(
    item: EditableItem,
    onChange: ((EditableItem) -> EditableItem) -> Unit,
    onRemove: () -> Unit,
    canRemove: Boolean,
    showTaxDiscount: Boolean,
) {
    OutlinedCard(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
        Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = item.title,
                    onValueChange = { v -> onChange { it.copy(title = v) } },
                    placeholder = { Text("نام کالا یا خدمات", style = MaterialTheme.typography.bodySmall) },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium,
                )
                if (canRemove) {
                    IconButton(onClick = onRemove) {
                        Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f))
                    }
                }
            }
            // اطلاعات انبار: موجودی و هشدار کمبود
            if (item.productId != null && item.availableStock != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.Inventory2,
                        null,
                        Modifier.size(13.dp),
                        tint = if (item.exceedsStock) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        if (item.exceedsStock) {
                            "بیش از موجودی! انبار: ${PersianFormatter.formatQuantity(item.availableStock)} ${item.unit}"
                        } else {
                            "موجودی انبار: ${PersianFormatter.formatQuantity(item.availableStock)} ${item.unit}"
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = if (item.exceedsStock) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedTextField(
                    value = item.quantity,
                    onValueChange = { v -> onChange { it.copy(quantity = v) } },
                    label = { Text("تعداد") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    textStyle = MaterialTheme.typography.bodySmall,
                )
                OutlinedTextField(
                    value = item.unitPrice,
                    onValueChange = { v -> onChange { it.copy(unitPrice = v) } },
                    label = { Text("قیمت واحد") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.weight(1.6f),
                    textStyle = MaterialTheme.typography.bodySmall,
                )
            }
            if (showTaxDiscount) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = item.discountPercent,
                        onValueChange = { v -> onChange { it.copy(discountPercent = v) } },
                        label = { Text("تخفیف٪") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        textStyle = MaterialTheme.typography.bodySmall,
                    )
                    OutlinedTextField(
                        value = item.taxPercent,
                        onValueChange = { v -> onChange { it.copy(taxPercent = v) } },
                        label = { Text("مالیات٪") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        textStyle = MaterialTheme.typography.bodySmall,
                    )
                    // مبلغ سطر به‌صورت زنده
                    val proto = item.toDomain(0, 0, 0.0)
                    MoneyText(
                        proto.lineTotal,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.weight(1f).padding(start = 8.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun CustomerPickerDialog(
    customers: List<Customer>,
    onDismiss: () -> Unit,
    onSelect: (Customer?) -> Unit,
    onQuickCreate: (name: String, phone: String) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var quickName by remember { mutableStateOf("") }
    var quickPhone by remember { mutableStateOf("") }
    var showQuick by remember { mutableStateOf(false) }
    val filtered = remember(customers, query) {
        if (query.isBlank()) customers else customers.filter { it.name.contains(query) || it.phone.contains(query) }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب مشتری") },
        text = {
            Column {
                OutlinedTextField(
                    value = query, onValueChange = { query = it },
                    placeholder = { Text("جستجو…") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                androidx.compose.foundation.lazy.LazyColumn(Modifier.height(220.dp)) {
                    items(filtered, key = { it.id }) { c ->
                        Row(
                            Modifier.fillMaxWidth().clickable { onSelect(c) }.padding(vertical = 10.dp, horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(c.name, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                            Text(c.phone.toPersianDigits(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        HorizontalDivider()
                    }
                }
                if (showQuick) {
                    OutlinedTextField(value = quickName, onValueChange = { quickName = it }, label = { Text("نام مشتری جدید") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    Spacer(Modifier.height(6.dp))
                    OutlinedTextField(value = quickPhone, onValueChange = { quickPhone = it }, label = { Text("شماره تماس") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = { if (quickName.isNotBlank()) onQuickCreate(quickName, quickPhone) }, modifier = Modifier.fillMaxWidth()) {
                        Text("ثبت سریع و انتخاب")
                    }
                } else {
                    TextButton(onClick = { showQuick = true }, modifier = Modifier.fillMaxWidth()) {
                        Text("+ ثبت سریع مشتری جدید")
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("بستن") } },
    )
}

@Composable
private fun SignatureEntryDialog(
    onDismiss: () -> Unit,
    onSave: (android.graphics.Bitmap) -> Unit,
) {
    val padState = rememberSignaturePadState()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("امضا کنید") },
        text = { SignaturePad(state = padState) },
        confirmButton = {
            Button(onClick = { if (!padState.isEmpty) onSave(padState.toBitmap()) }, enabled = !padState.isEmpty) { Text("ذخیره امضا") }
        },
        dismissButton = {
            Row {
                TextButton(onClick = { padState.clear() }) { Text("پاک کردن") }
                TextButton(onClick = onDismiss) { Text("انصراف") }
            }
        },
    )
}

private suspend fun saveSignature(context: Context, bitmap: android.graphics.Bitmap, invoiceId: Long): String =
    withContext(Dispatchers.IO) {
        val dir = File(context.filesDir, "signatures").apply { mkdirs() }
        val file = File(dir, "sig_${invoiceId.takeIf { it > 0 } ?: UUID.randomUUID()}.png")
        file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        file.absolutePath
    }


/** انتخاب کالا از انبار برای افزودن به فاکتور */
@Composable
private fun ProductPickerDialog(
    products: List<ir.factoryar.core.domain.model.Product>,
    useWholesale: Boolean,
    onDismiss: () -> Unit,
    onSelect: (ir.factoryar.core.domain.model.Product) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val filtered = remember(products, query) {
        if (query.isBlank()) {
            products
        } else {
            products.filter {
                it.name.contains(query, ignoreCase = true) ||
                    it.barcode.contains(query, ignoreCase = true) ||
                    it.sku.contains(query, ignoreCase = true)
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب کالا از انبار") },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text("جستجوی کالا…") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                if (filtered.isEmpty()) {
                    Text(
                        "کالایی یافت نشد. ابتدا از بخش «انبار» کالا تعریف کنید.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    androidx.compose.foundation.lazy.LazyColumn(Modifier.height(300.dp)) {
                        items(filtered, key = { it.id }) { p ->
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable { onSelect(p) }
                                    .padding(vertical = 10.dp, horizontal = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(p.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                                    Text(
                                        if (p.isService) {
                                            "خدمات"
                                        } else {
                                            "موجودی: ${PersianFormatter.formatQuantity(p.stockQuantity)} ${p.unit}"
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        color = if (p.isOutOfStock) {
                                            MaterialTheme.colorScheme.error
                                        } else {
                                            MaterialTheme.colorScheme.onSurfaceVariant
                                        },
                                    )
                                }
                                MoneyText(p.priceFor(useWholesale), style = MaterialTheme.typography.labelLarge)
                            }
                            HorizontalDivider()
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("بستن") } },
    )
}
