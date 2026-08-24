package com.modir.forushgah.presentation.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState

@Composable
fun CustomerDetailRoute(
    onBack: () -> Unit,
    onEdit: () -> Unit,
    viewModel: CustomerDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    CustomerDetailScreen(state = state, onBack = onBack, onEdit = onEdit)
}

@Composable
fun CustomerDetailScreen(
    state: CustomerDetailUiState,
    onBack: () -> Unit,
    onEdit: () -> Unit,
) {
    val profile = state.profile
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("مشتری") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
                actions = {
                    if (profile != null) {
                        IconButton(onClick = onEdit) {
                            Icon(Icons.Filled.Edit, contentDescription = "ویرایش")
                        }
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                profile == null -> EmptyState(
                    title = "مشتری یافت نشد",
                    subtitle = "این مشتری دیگر در دسترس نیست",
                    ctaLabel = "بازگشت",
                    onCtaClick = onBack,
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(profile.customer.name, style = MaterialTheme.typography.titleLarge)
                            DetailRow("موبایل", profile.customer.mobile?.let { PersianNumberFormatter.toPersianDigits(it) })
                            DetailRow("شهر", profile.customer.city)
                            DetailRow("آدرس", profile.customer.address)
                            DetailRow("یادداشت", profile.customer.notes)
                        }
                    }
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("آمار", style = MaterialTheme.typography.titleMedium)
                            DetailRow(
                                "تعداد سفارش‌ها",
                                PersianNumberFormatter.toPersianDigits(profile.totalOrders.toString()),
                            )
                            MoneyRow("خرید کل", profile.totalPurchases)
                            MoneyRow("سود کل", profile.totalProfit)
                            MoneyRow("مطالبات باز", profile.outstandingReceivable)
                            Text(
                                "مقادیر مالی با فعال‌شدن موتور مالی (فاز ۴) به‌روز می‌شوند",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String?) {
    if (value.isNullOrBlank()) return
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

/** Money data hooks (spec §8) — wired to the profile model; values refresh
 * automatically once the Phase 4 financial engine populates them. */
@Composable
private fun MoneyRow(label: String, value: com.modir.forushgah.core.common.Money) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(value.toPersianDisplayString(), style = MaterialTheme.typography.bodyMedium)
    }
}
