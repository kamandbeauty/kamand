package com.forushyar.app.ui.orders

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.forushyar.app.R
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.data.local.entity.OrderItem
import com.forushyar.app.data.local.entity.OrderStatus
import com.forushyar.app.ui.home.StatusChip
import com.forushyar.app.util.FormatUtils
import kotlinx.coroutines.flow.collectLatest

@Composable
fun OrderDetailScreen(
    onBack: () -> Unit,
    viewModel: OrderDetailViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val deleteError = stringResource(R.string.order_delete_error)
    val statusError = stringResource(R.string.order_status_error)

    LaunchedEffect(viewModel) {
        viewModel.events.collectLatest { event ->
            when (event) {
                OrderDetailEvent.Deleted -> onBack()
                OrderDetailEvent.DeleteFailed -> snackbar.showSnackbar(deleteError)
                OrderDetailEvent.StatusChangeFailed -> snackbar.showSnackbar(statusError)
            }
        }
    }

    OrderDetailContent(
        state = state,
        snackbar = snackbar,
        onBack = onBack,
        onStatusChange = viewModel::changeStatus,
        onDelete = viewModel::deleteOrder
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OrderDetailContent(
    state: OrderDetailState,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onStatusChange: (OrderStatus) -> Unit,
    onDelete: () -> Unit
) {
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showStatusDialog by remember { mutableStateOf(false) }
    val details = state.details

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (details == null) stringResource(R.string.order_details)
                        else stringResource(R.string.order_number, FormatUtils.formatNumber(details.order.id))
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    if (details != null) {
                        IconButton(onClick = { showDeleteDialog = true }) {
                            Icon(
                                Icons.Outlined.Delete,
                                contentDescription = stringResource(R.string.delete_order),
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { paddingValues ->
        when {
            state.isLoading -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) { CircularProgressIndicator() }
            }
            details == null -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) { Text(stringResource(R.string.order_not_found)) }
            }
            else -> OrderDetailsList(
                details = details,
                productNames = state.productNames,
                modifier = Modifier.padding(paddingValues),
                onChangeStatus = { showStatusDialog = true }
            )
        }
    }

    if (showStatusDialog && details != null) {
        StatusPickerDialog(
            current = details.order.status,
            onDismiss = { showStatusDialog = false },
            onSelect = {
                onStatusChange(it)
                showStatusDialog = false
            }
        )
    }
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text(stringResource(R.string.delete_order_title)) },
            text = { Text(stringResource(R.string.delete_order_warning)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteDialog = false
                    onDelete()
                }) { Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

@Composable
private fun OrderDetailsList(
    details: OrderDetails,
    productNames: Map<Long, String>,
    modifier: Modifier = Modifier,
    onChangeStatus: () -> Unit
) {
    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    DetailRow(stringResource(R.string.order_customer), details.customer.name)
                    DetailRow(
                        stringResource(R.string.order_date),
                        FormatUtils.formatDateTime(details.order.createdAt)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        StatusChip(details.order.status)
                        OutlinedButton(onClick = onChangeStatus) {
                            Text(stringResource(R.string.change_order_status))
                        }
                    }
                }
            }
        }
        item {
            Text(
                stringResource(R.string.order_items),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }
        items(details.items, key = { it.id }) { item ->
            SavedOrderItem(
                item = item,
                name = productNames[item.productId]
                    ?: stringResource(R.string.deleted_product_number, FormatUtils.formatNumber(item.productId))
            )
        }
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    DetailRow(stringResource(R.string.order_total), FormatUtils.formatPrice(details.total))
                    DetailRow(stringResource(R.string.order_profit), FormatUtils.formatPrice(details.profit))
                    if (details.order.note.isNotBlank()) {
                        HorizontalDivider()
                        Text(
                            stringResource(R.string.order_note),
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.labelMedium
                        )
                        Text(details.order.note)
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun SavedOrderItem(item: OrderItem, name: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(name, fontWeight = FontWeight.SemiBold)
                Text(
                    stringResource(R.string.quantity_value, FormatUtils.formatNumber(item.quantity.toLong())),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            DetailRow(stringResource(R.string.product_buy_price), FormatUtils.formatPrice(item.buyPrice))
            DetailRow(stringResource(R.string.product_sell_price), FormatUtils.formatPrice(item.sellPrice))
            DetailRow(stringResource(R.string.item_total_label), FormatUtils.formatPrice(item.total))
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun StatusPickerDialog(
    current: OrderStatus,
    onDismiss: () -> Unit,
    onSelect: (OrderStatus) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.change_order_status)) },
        text = {
            Column {
                OrderStatus.entries.forEach { status ->
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onSelect(status) }.padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OrderStatusText(status)
                        if (status == current) Text("✓", color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

@Composable
private fun OrderStatusText(status: OrderStatus) {
    Text(
        stringResource(
            when (status) {
                OrderStatus.NEW -> R.string.order_status_new
                OrderStatus.PREPARING -> R.string.order_status_preparing
                OrderStatus.SENT -> R.string.order_status_sent
                OrderStatus.DELIVERED -> R.string.order_status_delivered
                OrderStatus.CANCELLED -> R.string.order_status_cancelled
            }
        )
    )
}
