package ir.factoryar.feature.invoices

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Print
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter.formatQuantity
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.printer.PrinterDevice
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip
import ir.factoryar.core.ui.components.SectionHeader
import kotlinx.coroutines.flow.collectLatest

@Composable
fun InvoiceDetailScreen(
    onBack: () -> Unit,
    onEdit: (Long) -> Unit,
    viewModel: InvoiceDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var showPrinterDialog by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    val btPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        if (grants.values.all { it }) {
            viewModel.loadPairedPrinters()
            showPrinterDialog = true
        }
    }

    LaunchedEffect(Unit) {
        viewModel.events.collectLatest { event ->
            when (event) {
                is InvoiceDetailEvent.Message -> snackbar.showSnackbar(event.text)
                InvoiceDetailEvent.Deleted -> onBack()
            }
        }
    }

    val details = state.details

    Scaffold(
        topBar = {
            FyTopBar(
                title = details?.invoice?.number?.toPersianDigits() ?: "فاکتور",
                onBack = onBack,
                actions = {
                    IconButton(onClick = { viewModel.sharePdf() }, enabled = !state.isBusy) {
                        Icon(Icons.Filled.Share, contentDescription = "اشتراک PDF")
                    }
                    IconButton(
                        onClick = {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                btPermissionLauncher.launch(
                                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN),
                                )
                            } else {
                                viewModel.loadPairedPrinters(); showPrinterDialog = true
                            }
                        },
                        enabled = !state.isBusy,
                    ) { Icon(Icons.Filled.Print, contentDescription = "چاپ") }
                    IconButton(onClick = { details?.let { onEdit(it.invoice.id) } }) {
                        Icon(Icons.Filled.Edit, contentDescription = "ویرایش")
                    }
                    IconButton(onClick = { confirmDelete = true }) {
                        Icon(Icons.Filled.Delete, contentDescription = "حذف", tint = MaterialTheme.colorScheme.error)
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        if (details == null) {
            Column(Modifier.padding(padding).fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }
        if (state.isBusy) {
            // لایه وضعیت در حال پردازش
        }
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(details.invoice.type.faName, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                            PaymentStatusChip(details.invoice)
                        }
                        Text("تاریخ صدور: ${JalaliConverter.fromEpochMillis(details.invoice.issueDate).format().toPersianDigits()}", style = MaterialTheme.typography.bodySmall)
                        details.invoice.dueDate?.let {
                            Text("سررسید: ${JalaliConverter.fromEpochMillis(it).format().toPersianDigits()}", style = MaterialTheme.typography.bodySmall)
                        }
                        Text("مشتری: ${details.customer?.name ?: "—"}", style = MaterialTheme.typography.bodyMedium)
                        details.customer?.phone?.takeIf { it.isNotBlank() }?.let {
                            Text("تماس: ${it.toPersianDigits()}", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
            item { SectionHeader(title = "اقلام") }
            items(details.items.size) { i ->
                val item = details.items[i]
                Row(Modifier.padding(horizontal = 4.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(item.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        Text(
                            "${formatQuantity(item.quantity)} × ${ir.factoryar.core.common.util.PersianFormatter.formatMoney(item.unitPrice)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    MoneyText(item.lineTotal, style = MaterialTheme.typography.bodyMedium)
                }
                if (i < details.items.lastIndex) HorizontalDivider()
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f))) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        DetailTotal("جمع اقلام", details.invoice.subtotal)
                        DetailTotal("تخفیف", details.invoice.discountTotal)
                        DetailTotal("مالیات", details.invoice.taxTotal)
                        HorizontalDivider()
                        Row {
                            Text("قابل پرداخت", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                            MoneyText(details.invoice.grandTotal, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                        }
                        if (details.invoice.paidAmount > 0) {
                            DetailTotal("پرداخت‌شده", details.invoice.paidAmount)
                            DetailTotal("مانده", details.invoice.remainingAmount)
                        }
                    }
                }
            }
            if (details.invoice.note.isNotBlank()) {
                item { Text("یادداشت: ${details.invoice.note}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
            if (details.invoice.status != PaymentStatus.PAID) {
                item {
                    Button(onClick = viewModel::markPaid, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Filled.CheckCircle, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("ثبت پرداخت کامل")
                    }
                }
            }
            item {
                OutlinedButton(onClick = { viewModel.sharePdf() }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Share, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("اشتراک‌گذاری PDF")
                }
                Spacer(Modifier.height(60.dp))
            }
        }
    }

    if (showPrinterDialog) {
        PrinterPickerDialog(
            printers = state.pairedPrinters,
            lastMac = state.settings.lastPrinterMac,
            paperSizeMm = state.settings.paperSizeMm,
            onDismiss = { showPrinterDialog = false },
            onPrint = { mac -> viewModel.print(mac); showPrinterDialog = false },
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("حذف فاکتور") },
            text = { Text("این فاکتور برای همیشه حذف شود؟") },
            confirmButton = { TextButton(onClick = { confirmDelete = false; viewModel.delete() }) { Text("حذف", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("انصراف") } },
        )
    }
}

@Composable
private fun DetailTotal(label: String, amount: Long) {
    Row {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        MoneyText(amount, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun PrinterPickerDialog(
    printers: List<PrinterDevice>,
    lastMac: String?,
    paperSizeMm: Int,
    onDismiss: () -> Unit,
    onPrint: (String?) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("چاپ فاکتور (کاغذ ${paperSizeMm}mm)".toPersianDigits()) },
        text = {
            Column {
                if (printers.isEmpty()) {
                    Text("هیچ چاپگر جفت‌شده‌ای یافت نشد. چاپگر را از تنظیمات بلوتوث گوشی جفت کنید.", style = MaterialTheme.typography.bodySmall)
                } else {
                    printers.forEach { p ->
                        TextButton(onClick = { onPrint(p.macAddress) }, modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.fillMaxWidth()) {
                                Icon(Icons.Filled.Print, null, Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(p.name + if (p.macAddress == lastMac) " (قبلی)" else "")
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
