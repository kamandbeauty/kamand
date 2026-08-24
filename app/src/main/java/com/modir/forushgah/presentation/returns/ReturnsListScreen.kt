package com.modir.forushgah.presentation.returns

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.modir.forushgah.data.local.dao.ReturnWithOrder
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.presentation.orders.persianLabel

@Composable
fun ReturnsListRoute(
    onBack: () -> Unit,
    onOrderClick: (Long) -> Unit,
    viewModel: ReturnsListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    ReturnsListScreen(
        state = state,
        onBack = onBack,
        onOrderClick = onOrderClick,
    )
}

/** Spec §28: returns overview. Tapping a row opens the owning order. */
@Composable
fun ReturnsListScreen(
    state: ReturnsListUiState,
    onBack: () -> Unit,
    onOrderClick: (Long) -> Unit,
) {
    Scaffold(topBar = {
        TopAppBar(
            title = { Text("مرجوعی‌ها") },
            navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
        )
    }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (!state.isLoading && state.returns.isEmpty()) {
                EmptyState(
                    title = "مرجوعی‌ای ثبت نشده",
                    subtitle = "وقتی مشتری کالایی را برگرداند، در این‌جا ثبت می‌شود",
                    ctaLabel = "بازگشت به سفارش‌ها",
                    onCtaClick = onBack,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp),
                ) {
                    items(state.returns, key = { it.returnRow.id }) { row ->
                        ReturnRow(row = row, onClick = { onOrderClick(row.returnRow.orderId) })
                    }
                }
            }
        }
    }
}

@Composable
private fun ReturnRow(row: ReturnWithOrder, onClick: () -> Unit) {
    val returnRow = row.returnRow
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(row.orderNumber, style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    row.customerName ?: "بدون مشتری",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    DateTimeFormatter.dateTime(returnRow.date),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            ReturnStatusChip(status = returnRow.status)
        }
    }
}

@Composable
private fun ReturnStatusChip(status: ReturnStatus) {
    val (label, color, container) = when (status) {
        ReturnStatus.REQUESTED, ReturnStatus.APPROVED ->
            Triple(status.persianLabel(), MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.primaryContainer)
        ReturnStatus.RECEIVED -> Triple(status.persianLabel(), MaterialTheme.colorScheme.tertiary, MaterialTheme.colorScheme.tertiaryContainer)
        ReturnStatus.REFUNDED ->
            Triple(status.persianLabel(), MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.primaryContainer)
        ReturnStatus.REJECTED -> Triple(status.persianLabel(), MaterialTheme.colorScheme.error, MaterialTheme.colorScheme.errorContainer)
    }
    Surface(shape = MaterialTheme.shapes.small, color = container) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
        )
    }
}
