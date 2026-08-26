package com.modir.forushgah.presentation.invoice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.Card
import androidx.compose.material3.ElevatedButton
import androidx.compose.material3.FilterChip
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.InvoiceFormatting
import com.modir.forushgah.core.common.PersianNumberFormatter

// Rubi palette — the invoice screens keep the reference app's exact colors
// (Rubi hardcodes these per-screen too).
private val RubiOrange = Color(0xFFF97316)
private val RubiCream = Color(0xFFFFFBEB)
private val Slate400 = Color(0xFF94A3B8)
private val Slate500 = Color(0xFF64748B)
private val Slate700 = Color(0xFF334155)
private val Slate800 = Color(0xFF1E293B)
private val CardGray = Color(0xFFF1F5F9)

@Composable
fun InvoiceCreateRoute(
    onSaved: (Long) -> Unit,
    onBack: () -> Unit,
    viewModel: InvoiceCreateViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    // Opening the product selector is now per-row («محصول» on a line) — the
    // header «افزودن آیتم» adds a free editable line directly, exactly like Rubi.
    var linkLineId by androidx.compose.runtime.mutableStateOf<Long?>(null)
    var showProductForm by androidx.compose.runtime.mutableStateOf(false)

    LaunchedEffect(state.savedOrderId) {
        state.savedOrderId?.let(onSaved)
    }
    LaunchedEffect(state.errors) {
        state.errors.firstOrNull()?.let { snackbarHostState.showSnackbar(it) }
    }

    InvoiceCreateScreen(
        state = state,
        showProductSelector = linkLineId != null,
        showProductForm = showProductForm,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onCustomerNameChange = viewModel::onCustomerNameChange,
        onCustomerPhoneChange = viewModel::onCustomerPhoneChange,
        onNumberChange = viewModel::onNumberChange,
        onDateChange = viewModel::onDateChange,
        onKindChange = viewModel::onKindChange,
        onPaymentTypeChange = viewModel::onPaymentTypeChange,
        onAddItem = { viewModel.onFreeItemAdded() },
        onLineTitleChange = viewModel::onLineTitleChange,
        onLineQuantityChange = viewModel::onLineQuantityChange,
        onLinePriceChange = viewModel::onLinePriceChange,
        onLineRemoved = viewModel::onLineRemoved,
        onLineProductClick = { id -> linkLineId = id },
        onDiscountChange = viewModel::onDiscountChange,
        onShippingFeeChange = viewModel::onShippingFeeChange,
        onNotesChange = viewModel::onNotesChange,
        onSelectorQueryChange = viewModel::onSelectorQueryChange,
        onProductSelected = { id, qty ->
            val target = linkLineId
            if (target != null) viewModel.onProductLinked(target, id, qty)
            linkLineId = null
        },
        onAddProductClick = { showProductForm = true },
        onCloseProductForm = { showProductForm = false },
        onProductCreated = viewModel::createProductFromInvoice,
        onDismissSelector = { linkLineId = null },
        onSave = viewModel::save,
    )
}

/**
 * Rubi «ایجاد فاکتور جدید» — field order, labels and the blue total bar
 * reproduce the reference create screen; product selection happens in the
 * Rubi-style bottom sheet (spec §4).
 */
@Composable
fun InvoiceCreateScreen(
    state: InvoiceCreateUiState,
    showProductSelector: Boolean,
    showProductForm: Boolean,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onCustomerNameChange: (String) -> Unit,
    onCustomerPhoneChange: (String) -> Unit,
    onNumberChange: (String) -> Unit,
    onDateChange: (String) -> Unit,
    onKindChange: (Boolean) -> Unit,
    onPaymentTypeChange: (Boolean) -> Unit,
    onAddItem: () -> Unit,
    onLineTitleChange: (Long, String) -> Unit,
    onLineQuantityChange: (Long, String) -> Unit,
    onLinePriceChange: (Long, String) -> Unit,
    onLineRemoved: (Long) -> Unit,
    onLineProductClick: (Long) -> Unit,
    onDiscountChange: (String) -> Unit,
    onShippingFeeChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSelectorQueryChange: (String) -> Unit,
    onProductSelected: (Long, Int) -> Unit,
    onAddProductClick: () -> Unit,
    onCloseProductForm: () -> Unit,
    onProductCreated: (String, String, String, String, String, String, String) -> String?,
    onDismissSelector: () -> Unit,
    onSave: () -> Unit,
) {
    Scaffold(
        containerColor = RubiCream,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (state.isEditMode) "ویرایش فاکتور" else "ایجاد فاکتور جدید",
                        fontWeight = FontWeight.W900,
                    )
                },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("بازگشت", color = Slate800) }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // ---- Customer & invoice metadata (Rubi card 1) ----
            Card {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = state.customerName,
                        onValueChange = onCustomerNameChange,
                        label = { Text(if (state.isPurchase) "نام تأمین‌کننده" else "نام مشتری") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = state.customerPhone,
                            onValueChange = onCustomerPhoneChange,
                            label = { Text("موبایل") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                        )
                        OutlinedTextField(
                            value = state.number,
                            onValueChange = onNumberChange,
                            label = { Text("شماره فاکتور") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = state.date,
                            onValueChange = onDateChange,
                            label = { Text("تاریخ شمسی") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = !state.isPurchase,
                            onClick = { onKindChange(false) },
                            label = { Text("فاکتور فروش") },
                        )
                        FilterChip(
                            selected = state.isPurchase,
                            onClick = { onKindChange(true) },
                            label = { Text("فاکتور خرید") },
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = state.cashPayment,
                            onClick = { onPaymentTypeChange(true) },
                            label = { Text("نقدی") },
                        )
                        FilterChip(
                            selected = !state.cashPayment,
                            onClick = { onPaymentTypeChange(false) },
                            label = { Text("قرضی") },
                        )
                    }
                }
            }

            // ---- Items table (Rubi) ----
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("جدول اقلام", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Slate800, modifier = Modifier.weight(1f))
                TextButton(onClick = onAddItem) {
                    Icon(Icons.Filled.Add, contentDescription = null, tint = RubiOrange)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("افزودن آیتم", color = RubiOrange, fontWeight = FontWeight.W800)
                }
            }
            state.lines.forEach { line ->
                InvoiceLineCard(
                    line = line,
                    onTitleChange = { onLineTitleChange(line.id, it) },
                    onQuantityChange = { onLineQuantityChange(line.id, it) },
                    onPriceChange = { onLinePriceChange(line.id, it) },
                    onRemove = { onLineRemoved(line.id) },
                    onProductClick = { onLineProductClick(line.id) },
                )
            }

            // ---- Rubi blue total bar ----
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(RubiOrange, MaterialTheme.shapes.medium)
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("جمع کل نهایی:", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                Text(
                    InvoiceFormatting.formatCurrency(state.total),
                    color = Color.White,
                    fontWeight = FontWeight.W900,
                    fontSize = 18.sp,
                )
            }

            // ---- Invoice detail (Rubi model fields: discount/shipping/debt/deposit/notes) ----
            Card {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("تفصیل فاکتور", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.W800, color = Slate800)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = state.discount,
                            onValueChange = onDiscountChange,
                            label = { Text("تخفیف (تومان)") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                        OutlinedTextField(
                            value = state.shippingFee,
                            onValueChange = onShippingFeeChange,
                            label = { Text("هزینه ارسال (تومان)") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                    }
                    OutlinedTextField(
                        value = state.notes,
                        onValueChange = onNotesChange,
                        label = { Text("یادداشت / توضیحات") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            // ---- Rubi save button ----
            ElevatedButton(
                onClick = onSave,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                enabled = !state.isSaving,
                shape = MaterialTheme.shapes.medium,
                colors = androidx.compose.material3.ButtonDefaults.elevatedButtonColors(containerColor = RubiOrange),
            ) {
                Icon(
                    if (state.isEditMode) Icons.Filled.Check else Icons.Filled.Save,
                    contentDescription = null,
                    tint = Color.White,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    if (state.isSaving) "در حال ذخیره…" else if (state.isEditMode) "ذخیره تغییرات" else "ذخیره فاکتور",
                    color = Color.White,
                    fontWeight = FontWeight.W800,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }

    if (showProductSelector) {
        // Product selection now opens from a specific line («محصول» button)
        // and fills that line — the header «افزودن آیتم» adds free rows
        // directly, exactly like Rubi.
        ProductSelectionSheet(
            products = state.selectorProducts,
            query = state.selectorQuery,
            isPurchase = state.isPurchase,
            onQueryChange = onSelectorQueryChange,
            onProductSelected = onProductSelected,
            onAddProductClick = onAddProductClick,
            onDismiss = onDismissSelector,
        )
    }
    if (showProductForm) {
        ProductFormSheet(
            onCreated = onProductCreated,
            onClose = onCloseProductForm,
        )
    }
}

/** One Rubi item card: «عنوان کالا / خدمت» + Row «مقدار»/«قیمت واحد». */
@Composable
private fun InvoiceLineCard(
    line: InvoiceLineUi,
    onTitleChange: (String) -> Unit,
    onQuantityChange: (String) -> Unit,
    onPriceChange: (String) -> Unit,
    onRemove: () -> Unit,
    onProductClick: () -> Unit,
) {
    Card {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = line.title,
                    onValueChange = onTitleChange,
                    label = { Text("عنوان کالا / خدمت") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                // Link this line to a real product (stock/price) — optional;
                // the line itself stays a plain Rubi row by default.
                TextButton(onClick = onProductClick) {
                    Text("محصول", color = RubiOrange, fontWeight = FontWeight.W800, fontSize = 12.sp)
                }
                IconButton(onClick = onRemove) {
                    Icon(Icons.Filled.Delete, contentDescription = "حذف قلم", tint = Color(0xFFE11D48))
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = line.quantity,
                    onValueChange = onQuantityChange,
                    label = { Text("مقدار") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = line.unitPrice,
                    onValueChange = onPriceChange,
                    label = { Text("قیمت واحد") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "واحد: ${line.unit}   •   جمع ردیف: ${InvoiceFormatting.formatCurrency(line.lineTotal)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Slate500,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
