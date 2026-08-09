package ir.factoryar.feature.customers

import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.components.StatCard
import ir.factoryar.core.ui.components.FyTopBar

@Composable
fun CustomerDetailScreen(
    onBack: () -> Unit,
    onInvoiceClick: (Long) -> Unit,
    onNewInvoiceForCustomer: (Long) -> Unit,
    viewModel: CustomerDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val ledger = state.ledger
    var showEditor by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            FyTopBar(
                title = ledger?.customer?.name ?: "مشتری",
                onBack = onBack,
                actions = {
                    IconButton(onClick = { showEditor = true }) { Icon(Icons.Filled.Edit, contentDescription = "ویرایش") }
                    IconButton(onClick = { confirmDelete = true }) { Icon(Icons.Filled.Delete, contentDescription = "حذف", tint = MaterialTheme.colorScheme.error) }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            ledger ?: return@LazyColumn
            item {
                // کارت اطلاعات تماس
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (ledger.customer.phone.isNotBlank()) Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Phone, null, Modifier.padding(end = 6.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(ledger.customer.phone.toPersianDigits(), style = MaterialTheme.typography.bodyMedium)
                        }
                        if (ledger.customer.address.isNotBlank()) Text(ledger.customer.address, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (ledger.customer.email.isNotBlank()) Text(ledger.customer.email, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        ledger.customer.note.takeIf { it.isNotBlank() }?.let {
                            Text("یادداشت: $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = if (ledger.totalDebt > 0) {
                            MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f)
                        } else {
                            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)
                        },
                    ),
                ) {
                    Column(Modifier.padding(14.dp)) {
                        Text("مانده حساب", style = MaterialTheme.typography.labelMedium)
                        MoneyText(ledger.totalDebt, style = MaterialTheme.typography.headlineSmall)
                        val last = ledger.invoices.maxByOrNull { it.issueDate }?.issueDate
                        Text(
                            "آخرین خرید: " + (last?.let { JalaliConverter.fromEpochMillis(it).format().toPersianDigits() } ?: "—"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    StatCard(
                        title = "تعداد فاکتور",
                        value = ledger.invoices.size.toString().toPersianDigits(),
                        modifier = Modifier.weight(1f),
                    )
                    Card(
                        modifier = Modifier.weight(1f),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text("مجموع خرید", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.height(8.dp))
                            MoneyText(ledger.totalSales, style = MaterialTheme.typography.titleLarge)
                        }
                    }
                }
            }
            item {
                OutlinedButton(onClick = { onNewInvoiceForCustomer(ledger.customer.id) }, modifier = Modifier.fillMaxWidth()) {
                    Text("صدور فاکتور جدید برای این مشتری")
                }
            }
            item { SectionHeader(title = "تاریخچه تراکنش‌ها") }
            if (ledger.invoices.isEmpty()) {
                item { Text("تراکنشی ثبت نشده است.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp)) }
            } else {
                items(ledger.invoices, key = { it.id }) { invoice ->
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable { onInvoiceClick(invoice.id) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    ) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(invoice.number.toPersianDigits(), style = MaterialTheme.typography.titleSmall)
                                Text(JalaliConverter.fromEpochMillis(invoice.issueDate).format().toPersianDigits(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                MoneyText(invoice.grandTotal, style = MaterialTheme.typography.titleSmall)
                                PaymentStatusChip(invoice)
                            }
                        }
                    }
                }
            }
        }
    }

    if (showEditor && ledger != null) {
        CustomerEditorDialog(
            initial = ledger.customer,
            onDismiss = { showEditor = false },
            onSave = { viewModel.save(it); showEditor = false },
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("حذف مشتری") },
            text = { Text("مشتری حذف شود؟ فاکتورهای قبلی باقی می‌مانند ولی ارتباطشان با مشتری قطع می‌شود.") },
            confirmButton = { TextButton(onClick = { confirmDelete = false; viewModel.delete { onBack() } }) { Text("حذف", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("انصراف") } },
        )
    }
}
