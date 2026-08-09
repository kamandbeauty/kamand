package ir.factoryar.feature.invoices

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip
import ir.factoryar.core.ui.components.SearchField

@Composable
fun InvoicesScreen(
    onInvoiceClick: (Long) -> Unit,
    onNewInvoice: (InvoiceType) -> Unit,
    onOpenRecurring: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    viewModel: InvoicesViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showTypeMenu by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            FyTopBar(
                title = "فاکتورها",
                onBack = onBack,
                actions = {
                    if (onOpenRecurring != null) {
                        androidx.compose.material3.IconButton(onClick = onOpenRecurring) {
                            Icon(Icons.Filled.Repeat, contentDescription = "فاکتورهای دوره‌ای")
                        }
                    }
                },
            )
        },
        floatingActionButton = {
            Column(horizontalAlignment = Alignment.End) {
                DropdownMenu(expanded = showTypeMenu, onDismissRequest = { showTypeMenu = false }) {
                    InvoiceType.entries.forEach { type ->
                        DropdownMenuItem(
                            text = { Text(type.faName) },
                            leadingIcon = {
                                Icon(
                                    when (type) {
                                        InvoiceType.PROFORMA -> Icons.Filled.Description
                                        InvoiceType.SALE -> Icons.Filled.Receipt
                                        InvoiceType.PURCHASE -> Icons.Filled.ShoppingCart
                                    },
                                    contentDescription = null,
                                )
                            },
                            onClick = { showTypeMenu = false; onNewInvoice(type) },
                        )
                    }
                }
                ExtendedFloatingActionButton(
                    onClick = { showTypeMenu = true },
                    icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                    text = { Text("فاکتور جدید") },
                )
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            SearchField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                placeholder = "جستجوی شماره یا نام مشتری…",
            )
            // فیلتر نوع
            Row(
                Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(selected = state.filter.type == null && !state.filter.overdueOnly, onClick = { viewModel.setType(null) }, label = { Text("همه") })
                InvoiceType.entries.forEach { type ->
                    FilterChip(
                        selected = state.filter.type == type,
                        onClick = { viewModel.setType(if (state.filter.type == type) null else type) },
                        label = { Text(type.faName) },
                    )
                }
            }
            Spacer(Modifier.height(4.dp))
            // فیلتر وضعیت
            Row(
                Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(selected = state.filter.status == null && !state.filter.overdueOnly, onClick = { viewModel.setStatus(null) }, label = { Text("همه وضعیت‌ها") })
                FilterChip(selected = state.filter.status == PaymentStatus.PAID, onClick = { viewModel.setStatus(PaymentStatus.PAID) }, label = { Text("پرداخت‌شده") })
                FilterChip(selected = state.filter.status == PaymentStatus.PARTIAL, onClick = { viewModel.setStatus(PaymentStatus.PARTIAL) }, label = { Text("پرداخت جزئی") })
                FilterChip(selected = state.filter.overdueOnly, onClick = { viewModel.setOverdueOnly() }, label = { Text("معوق") })
            }
            Spacer(Modifier.height(4.dp))
            if (state.isEmpty) {
                EmptyState(
                    icon = Icons.Filled.Receipt,
                    title = "فاکتوری یافت نشد",
                    description = "اولین فاکتور خود را با دکمه «فاکتور جدید» صادر کنید.",
                    modifier = Modifier.weight(1f),
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.invoices, key = { it.invoice.id }) { details ->
                        InvoiceListRow(details, onClick = { onInvoiceClick(details.invoice.id) })
                    }
                    item { Spacer(Modifier.height(80.dp)) }
                }
            }
        }
    }
}

@Composable
private fun InvoiceListRow(details: InvoiceWithDetails, onClick: () -> Unit) {
    val inv = details.invoice
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(inv.number.toPersianDigits(), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        inv.type.faName,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    details.customer?.name ?: "مشتری نامشخص",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    JalaliConverter.fromEpochMillis(inv.issueDate).format().toPersianDigits(),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.width(8.dp))
            Column(horizontalAlignment = Alignment.End) {
                MoneyText(inv.grandTotal, style = MaterialTheme.typography.titleSmall)
                Spacer(Modifier.height(4.dp))
                PaymentStatusChip(inv)
            }
        }
    }
}
