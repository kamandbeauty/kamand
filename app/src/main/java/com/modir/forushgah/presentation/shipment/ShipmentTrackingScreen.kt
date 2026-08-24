package com.modir.forushgah.presentation.shipment

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.PersianNumberFormatter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val TrackCream = androidx.compose.ui.graphics.Color(0xFFFFFBEB)
private val TrackOrange = androidx.compose.ui.graphics.Color(0xFFF97316)
private val TrackSlate400 = androidx.compose.ui.graphics.Color(0xFF94A3B8)
private val TrackSlate500 = androidx.compose.ui.graphics.Color(0xFF64748B)
private val TrackSlate800 = androidx.compose.ui.graphics.Color(0xFF1E293B)
private val TrackBorder = androidx.compose.ui.graphics.Color(0xFFE2E8F0)

@Composable
fun ShipmentTrackingRoute(
    onBack: () -> Unit,
    onCustomerEdit: (Long) -> Unit,
    viewModel: ShipmentTrackingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var missingPhoneRow by remember { mutableStateOf<TrackingRowUi?>(null) }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.onMessageShown()
        }
    }

    ShipmentTrackingScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        missingPhoneRow = missingPhoneRow,
        onBack = onBack,
        onQueryChange = viewModel::onQueryChange,
        onFilterChange = viewModel::onFilterChange,
        onTrackingCodeChange = viewModel::onTrackingCodeChange,
        onProviderChange = viewModel::onProviderChange,
        onDateChange = viewModel::onDateChange,
        onToggleSelection = viewModel::toggleSelection,
        onSelectAll = viewModel::selectAllVisible,
        onClearSelection = viewModel::clearSelection,
        onBulkSave = viewModel::bulkSave,
        onSendSms = { row ->
            val intent = viewModel.smsIntent(row)
            if (intent == null) {
                missingPhoneRow = row
            } else {
                context.startActivity(intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        },
        onShare = { row ->
            viewModel.shareIntent(row)?.let {
                context.startActivity(
                    android.content.Intent.createChooser(it, "اشتراک‌گذاری کد رهگیری")
                        .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }
        },
        onMultiShare = {
            val rows = state.shareableSelected
            if (rows.isEmpty()) {
                snackbarHostState.showSnackbar("برای اشتراک‌گذاری، ابتدا کد رهگیری را ذخیره کنید")
            } else {
                multiShare(rows, viewModel, snackbarHostState, scope, context)
            }
        },
        onMissingPhoneDismiss = { missingPhoneRow = null },
        onMissingPhoneEdit = { row ->
            row?.customerId?.let(onCustomerEdit)
            missingPhoneRow = null
        },
    )
}

/** Spec §35: each selected order gets its OWN separate share sheet —
 * customers are never combined into one message. */
private fun multiShare(
    rows: List<TrackingRowUi>,
    viewModel: ShipmentTrackingViewModel,
    snackbarHostState: SnackbarHostState,
    scope: kotlinx.coroutines.CoroutineScope,
    context: android.content.Context,
) {
    scope.launch {
        rows.forEachIndexed { index, row ->
            snackbarHostState.showSnackbar(
                "${row.customerName} — فاکتور #${PersianNumberFormatter.toPersianDigits(row.orderNumber)}",
            )
            viewModel.shareIntent(row)?.let {
                context.startActivity(
                    android.content.Intent.createChooser(it, "اشتراک‌گذاری کد رهگیری")
                        .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }
            if (index < rows.lastIndex) delay(400)
        }
    }
}

/**
 * «کدهای رهگیری ارسال» — bulk shipment tracking (Phase 3.1 Premium).
 * One row per ORDER (never grouped by customer); no address anywhere
 * (completely out of scope, spec §17).
 */
@Composable
fun ShipmentTrackingScreen(
    state: ShipmentTrackingUiState,
    snackbarHostState: SnackbarHostState,
    missingPhoneRow: TrackingRowUi?,
    onBack: () -> Unit,
    onQueryChange: (String) -> Unit,
    onFilterChange: (ShipmentFilter) -> Unit,
    onTrackingCodeChange: (Long, String) -> Unit,
    onProviderChange: (Long, Long?) -> Unit,
    onDateChange: (Long, String) -> Unit,
    onToggleSelection: (Long) -> Unit,
    onSelectAll: () -> Unit,
    onClearSelection: () -> Unit,
    onBulkSave: () -> Unit,
    onSendSms: (TrackingRowUi) -> Unit,
    onShare: (TrackingRowUi) -> Unit,
    onMultiShare: () -> Unit,
    onMissingPhoneDismiss: () -> Unit,
    onMissingPhoneEdit: (TrackingRowUi?) -> Unit,
) {
    Scaffold(
        backgroundColor = TrackCream,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                backgroundColor = TrackCream,
                title = {
                    Text(
                        "کدهای رهگیری ارسال",
                        fontWeight = FontWeight.W900,
                        color = TrackSlate800,
                    )
                },
                navigationIcon = {
                    TextButton(onClick = onBack) {
                        Text("بازگشت", color = TrackSlate800)
                    }
                },
            )
        },
        bottomBar = {
            Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                Button(
                    onClick = onBulkSave,
                    enabled = state.dirtyCount > 0 && !state.isSaving,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    containerColor = TrackOrange,
                ) {
                    Text(
                        if (state.isSaving) "در حال ذخیره…"
                        else "ثبت اطلاعات ارسال" +
                            (if (state.dirtyCount > 0) " (${PersianNumberFormatter.toPersianDigits(state.dirtyCount.toString())})" else ""),
                        color = androidx.compose.ui.graphics.Color.White,
                        fontWeight = FontWeight.W900,
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(
                    onClick = onMultiShare,
                    enabled = state.shareableSelected.isNotEmpty(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, TrackBorder),
                ) {
                    Icon(Icons.Outlined.Share, contentDescription = null, modifier = Modifier.width(18.dp).height(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        "اشتراک‌گذاری کدهای رهگیری" +
                            (if (state.selectedOrderIds.isNotEmpty())
                                " (${PersianNumberFormatter.toPersianDigits(state.shareableSelected.size.toString())})" else ""),
                        fontWeight = FontWeight.W800,
                        fontSize = 12.sp,
                    )
                }
            }
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // Search by customer name (spec §24)
            com.modir.forushgah.presentation.common.SearchField(
                query = state.query,
                onQueryChange = onQueryChange,
                placeholder = "جستجوی نام مشتری...",
            )
            // Filters (spec §25)
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(
                    selected = state.filter == ShipmentFilter.ALL,
                    onClick = { onFilterChange(ShipmentFilter.ALL) },
                    label = { Text("همه") },
                )
                FilterChip(
                    selected = state.filter == ShipmentFilter.NOT_SHIPPED,
                    onClick = { onFilterChange(ShipmentFilter.NOT_SHIPPED) },
                    label = { Text("ارسال نشده") },
                )
                FilterChip(
                    selected = state.filter == ShipmentFilter.NO_TRACKING,
                    onClick = { onFilterChange(ShipmentFilter.NO_TRACKING) },
                    label = { Text("کد رهگیری ثبت نشده") },
                )
                FilterChip(
                    selected = state.filter == ShipmentFilter.SHIPPED,
                    onClick = { onFilterChange(ShipmentFilter.SHIPPED) },
                    label = { Text("ارسال شده") },
                )
            }
            // Select-all helper
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(
                    checked = state.rows.isNotEmpty() && state.rows.all { it.orderId in state.selectedOrderIds },
                    onCheckedChange = { if (it) onSelectAll() else onClearSelection() },
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    "انتخاب همهٔ نمایش‌داده‌شده‌ها",
                    style = MaterialTheme.typography.bodySmall,
                    color = TrackSlate500,
                )
            }
            if (state.isLoading) {
                androidx.compose.material3.CircularProgressIndicator(
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .padding(24.dp),
                )
            } else if (state.rows.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        "سفارشی برای نمایش نیست",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.W800,
                        color = TrackSlate500,
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        if (state.query.isNotBlank()) "سفارشی با این نام پیدا نشد" else "سفارش‌های جدید اینجا نمایش داده می‌شوند",
                        style = MaterialTheme.typography.bodySmall,
                        color = TrackSlate400,
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(state.rows, key = { it.orderId }) { row ->
                        TrackingRowCard(
                            row = row,
                            providers = state.providers,
                            selected = row.orderId in state.selectedOrderIds,
                            onToggleSelection = { onToggleSelection(row.orderId) },
                            onTrackingCodeChange = { onTrackingCodeChange(row.orderId, it) },
                            onProviderChange = { onProviderChange(row.orderId, it) },
                            onDateChange = { onDateChange(row.orderId, it) },
                            onSendSms = { onSendSms(row) },
                            onShare = { onShare(row) },
                        )
                    }
                }
            }
        }
    }

    if (missingPhoneRow != null) {
        AlertDialog(
            onDismissRequest = onMissingPhoneDismiss,
            title = { Text("ارسال پیامک") },
            text = { Text("شماره موبایل مشتری ثبت نشده است.") },
            confirmButton = {
                TextButton(onClick = { onMissingPhoneEdit(missingPhoneRow) }) {
                    Text("ویرایش مشتری")
                }
            },
            dismissButton = {
                TextButton(onClick = onMissingPhoneDismiss) {
                    Text("بستن")
                }
            },
        )
    }
}

/** One order's tracking card (spec §17 — exactly these five pieces of data,
 * no address). */
@Composable
private fun TrackingRowCard(
    row: TrackingRowUi,
    providers: List<com.modir.forushgah.domain.model.ShippingProvider>,
    selected: Boolean,
    onToggleSelection: () -> Unit,
    onTrackingCodeChange: (String) -> Unit,
    onProviderChange: (Long?) -> Unit,
    onDateChange: (String) -> Unit,
    onSendSms: () -> Unit,
    onShare: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            // Header: checkbox + customer + invoice number (spec §18/§19/§20)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = selected, onCheckedChange = { onToggleSelection() })
                Text(
                    row.customerName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.W800,
                    color = TrackSlate800,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
                Text(
                    "فاکتور #${PersianNumberFormatter.toPersianDigits(row.orderNumber)}" +
                        (if (row.isPurchase) "  •  خرید" else ""),
                    style = MaterialTheme.typography.bodySmall,
                    color = TrackSlate500,
                )
                if (row.dirty) {
                    Spacer(modifier = Modifier.width(6.dp))
                    androidx.compose.material3.Surface(
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
                        color = TrackOrange.copy(alpha = 0.12f),
                    ) {
                        Text(
                            "تغییر داده",
                            style = MaterialTheme.typography.labelSmall,
                            color = TrackOrange,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            // Tracking code — String, exactly as typed (spec §21)
            OutlinedTextField(
                value = row.trackingCode,
                onValueChange = onTrackingCodeChange,
                label = { Text("کد رهگیری") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = row.dateText,
                    onValueChange = onDateChange,
                    label = { Text("تاریخ ارسال") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                )
                ProviderPicker(
                    providers = providers,
                    selectedId = row.providerId,
                    selectedName = row.providerName,
                    onProviderChange = onProviderChange,
                )
            }
            // Per-row tracking actions (spec §31/§33/§34)
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(onClick = onSendSms, enabled = row.hasTracking) {
                    Icon(Icons.Filled.Send, contentDescription = null, modifier = Modifier.width(16.dp).height(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("ارسال کد رهگیری", fontSize = 12.sp)
                }
                TextButton(onClick = onShare, enabled = row.hasTracking) {
                    Icon(Icons.Outlined.Share, contentDescription = null, modifier = Modifier.width(16.dp).height(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("اشتراک‌گذاری", fontSize = 12.sp)
                }
            }
        }
    }
}

/** «روش ارسال» — the existing Phase 3 shipping providers (spec §22). */
@Composable
private fun ProviderPicker(
    providers: List<com.modir.forushgah.domain.model.ShippingProvider>,
    selectedId: Long?,
    selectedName: String?,
    onProviderChange: (Long?) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.weight(1f),
            shape = MaterialTheme.shapes.small,
        ) {
            Text(
                selectedName ?: "روش ارسال",
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyMedium,
            )
            Icon(
                Icons.Filled.ArrowDropDown,
                contentDescription = null,
                modifier = Modifier
                    .width(18.dp)
                    .height(18.dp),
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            providers.forEach { provider ->
                DropdownMenuItem(
                    text = { Text(provider.name) },
                    trailingIcon = {
                        if (provider.id == selectedId) {
                            Icon(Icons.Filled.Check, contentDescription = null)
                        }
                    },
                    onClick = {
                        expanded = false
                        onProviderChange(if (provider.id == selectedId) null else provider.id)
                    },
                )
            }
        }
    }
}
