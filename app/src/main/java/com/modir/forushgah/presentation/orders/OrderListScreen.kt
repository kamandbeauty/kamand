package com.modir.forushgah.presentation.orders

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.DateTimeFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.data.local.dao.OrderWithCustomer
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.presentation.common.SearchField

@Composable
fun OrderListRoute(
    onOrderClick: (Long) -> Unit,
    onAddOrder: () -> Unit,
    onReturnsClick: () -> Unit,
    viewModel: OrderListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    OrderListScreen(
        state = state,
        onQueryChange = viewModel::onQueryChange,
        onStatusSelected = viewModel::onStatusSelected,
        onOrderClick = onOrderClick,
        onAddOrder = onAddOrder,
        onReturnsClick = onReturnsClick,
    )
}

@Composable
fun OrderListScreen(
    state: OrderListUiState,
    onQueryChange: (String) -> Unit,
    onStatusSelected: (OrderStatus?) -> Unit,
    onOrderClick: (Long) -> Unit,
    onAddOrder: () -> Unit,
    onReturnsClick: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("سفارش‌ها") },
                actions = {
                    IconButton(onClick = onReturnsClick) {
                        Icon(Icons.Filled.History, contentDescription = "مرجوعی‌ها")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddOrder) {
                Icon(Icons.Filled.Add, contentDescription = "ثبت سفارش")
            }
        },
    ) { padding ->
        if (state.isEmpty) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                EmptyState(
                    title = "هنوز سفارشی ثبت نشده",
                    subtitle = "اولین سفارش مشتری‌تان را ثبت کنید تا در این‌جا ببینید",
                    ctaLabel = "ثبت اولین سفارش",
                    onCtaClick = onAddOrder,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
        } else {
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                SearchField(
                    query = state.query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی شماره سفارش یا مشتری",
                )
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item {
                        FilterChip(
                            selected = state.selectedStatus == null,
                            onClick = { onStatusSelected(null) },
                            label = { Text("همه") },
                        )
                    }
                    items(OrderStatus.entries.filter { it != OrderStatus.CONFIRMED }) { status ->
                        FilterChip(
                            selected = state.selectedStatus == status,
                            onClick = { onStatusSelected(status) },
                            label = { Text(status.persianLabel()) },
                        )
                    }
                }
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(state.orders, key = { it.order.id }) { row ->
                        OrderRow(row = row, onClick = { onOrderClick(row.order.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun OrderRow(row: OrderWithCustomer, onClick: () -> Unit) {
    val order = row.order
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(order.orderNumber, style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    row.customerName ?: "بدون مشتری",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    StatusBadge(status = order.status)
                    if (order.shippingPaymentType == ShippingPaymentType.COD) {
                        IndicatorChip("پس‌کرایه")
                    }
                    if (row.paymentMethodName != null && row.paymentMethodName.contains("اقساطی")) {
                        IndicatorChip("اقساطی")
                    }
                    if (!row.isFullyPaid && order.status != OrderStatus.CANCELLED) {
                        IndicatorChip("پرداخت باقی‌مانده")
                    }
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    row.totalCustomerPayment.toPersianDisplayString(),
                    style = MaterialTheme.typography.titleMedium,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    DateTimeFormatter.date(order.orderDate),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
internal fun StatusBadge(status: OrderStatus) {
    val (label, color, container) = when (status) {
        OrderStatus.NEW -> Triple(status.persianLabel(), MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.primaryContainer)
        OrderStatus.CONFIRMED, OrderStatus.PREPARING ->
            Triple(status.persianLabel(), MaterialTheme.colorScheme.tertiary, MaterialTheme.colorScheme.tertiaryContainer)
        OrderStatus.SHIPPED, OrderStatus.DELIVERED ->
            Triple(status.persianLabel(), MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.primaryContainer)
        OrderStatus.RETURNED -> Triple(status.persianLabel(), MaterialTheme.colorScheme.error, MaterialTheme.colorScheme.errorContainer)
        OrderStatus.CANCELLED, OrderStatus.DELETED ->
            Triple(status.persianLabel(), MaterialTheme.colorScheme.onSurfaceVariant, MaterialTheme.colorScheme.surfaceVariant)
    }
    Surface(shape = MaterialTheme.shapes.small, color = container) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
        )
    }
}

@Composable
private fun IndicatorChip(label: String) {
    Surface(shape = MaterialTheme.shapes.small, color = MaterialTheme.colorScheme.surfaceVariant) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
        )
    }
}
