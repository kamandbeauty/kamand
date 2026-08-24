package com.modir.forushgah.presentation.suppliers

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material3.Divider
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import com.modir.forushgah.domain.model.Supplier
import com.modir.forushgah.presentation.common.SearchField

@Composable
fun SupplierListRoute(
    onSupplierClick: (Long) -> Unit,
    onAddSupplier: () -> Unit,
    viewModel: SupplierListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    SupplierListScreen(
        state = state,
        onQueryChange = viewModel::onQueryChange,
        onSupplierClick = onSupplierClick,
        onAddSupplier = onAddSupplier,
    )
}

@Composable
fun SupplierListScreen(
    state: SupplierListUiState,
    onQueryChange: (String) -> Unit,
    onSupplierClick: (Long) -> Unit,
    onAddSupplier: () -> Unit,
) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("تأمین‌کنندگان") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddSupplier) {
                Icon(Icons.Filled.Add, contentDescription = "افزودن تأمین‌کننده")
            }
        },
    ) { padding ->
        if (state.isEmpty) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                EmptyState(
                    title = "هنوز تأمین‌کننده‌ای ثبت نشده",
                    subtitle = "تأمین‌کنندگان خود را اضافه کنید تا خرید کالا ثبت شود",
                    ctaLabel = "افزودن تأمین‌کننده",
                    onCtaClick = onAddSupplier,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
        } else {
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                SearchField(
                    query = state.query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی تأمین‌کننده",
                )
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(state.suppliers, key = { it.id }) { supplier ->
                        SupplierRow(supplier = supplier, onClick = { onSupplierClick(supplier.id) })
                        Divider()
                    }
                }
            }
        }
    }
}

@Composable
private fun SupplierRow(supplier: Supplier, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .background(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.LocalShipping,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(supplier.name, style = MaterialTheme.typography.titleMedium, maxLines = 1)
            if (supplier.phone != null) {
                Text(
                    PersianNumberFormatter.toPersianDigits(supplier.phone),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
