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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PictureAsPdf
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
    var confirmDelete by remember { mutableStateOf(false) }

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
                    IconButton(onClick = { viewModel.shareBoth() }, enabled = !state.isBusy) {
                        Icon(Icons.Filled.Share, contentDescription = "اشتراک‌گذاری")
                    }
                    IconButton(onClick = { viewModel.openPdf() }, enabled = !state.isBusy) {
                        Icon(Icons.Filled.PictureAsPdf, contentDescription = "نمایش PDF")
                    }
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
                SectionHeader(title = "خروجی و اشتراک‌گذاری")
                Column(
                    Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Button(
                        onClick = { viewModel.shareBoth() },
                        enabled = !state.isBusy,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.Filled.Share, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("ارسال فاکتور (PDF و تصویر)")
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = { viewModel.sharePdf() },
                            enabled = !state.isBusy,
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.Filled.PictureAsPdf, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("فقط PDF")
                        }
                        OutlinedButton(
                            onClick = { viewModel.shareImage() },
                            enabled = !state.isBusy,
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.Filled.Image, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("فقط تصویر")
                        }
                    }
                }
                Spacer(Modifier.height(60.dp))
            }
        }
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
