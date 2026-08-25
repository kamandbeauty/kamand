package com.modir.forushgah.presentation.customers

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
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
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.presentation.common.SearchField

@Composable
fun CustomerListRoute(
    onCustomerClick: (Long) -> Unit,
    onAddCustomer: () -> Unit,
    viewModel: CustomerListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    CustomerListScreen(
        state = state,
        onQueryChange = viewModel::onQueryChange,
        onCustomerClick = onCustomerClick,
        onAddCustomer = onAddCustomer,
    )
}

@Composable
fun CustomerListScreen(
    state: CustomerListUiState,
    onQueryChange: (String) -> Unit,
    onCustomerClick: (Long) -> Unit,
    onAddCustomer: () -> Unit,
) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("مشتریان") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddCustomer) {
                Icon(Icons.Filled.Add, contentDescription = "افزودن مشتری")
            }
        },
    ) { padding ->
        if (state.isEmpty) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                EmptyState(
                    title = "هنوز مشتری‌ای ثبت نشده",
                    subtitle = "مشتریان خود را اضافه کنید تا در ثبت سفارش‌ها در دسترس باشند",
                    ctaLabel = "افزودن مشتری",
                    onCtaClick = onAddCustomer,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
        } else {
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                SearchField(
                    query = state.query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی مشتری",
                )
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(state.customers, key = { it.id }) { customer ->
                        CustomerRow(customer = customer, onClick = { onCustomerClick(customer.id) })
                        Divider()
                    }
                }
            }
        }
    }
}

@Composable
private fun CustomerRow(customer: Customer, onClick: () -> Unit) {
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
                .background(color = MaterialTheme.colorScheme.surfaceVariant, shape = CircleShape()),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = customer.name.firstOrNull()?.toString() ?: "؟",
                style = MaterialTheme.typography.titleMedium,
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(customer.name, style = MaterialTheme.typography.titleMedium, maxLines = 1)
            if (customer.mobile != null) {
                Text(
                    PersianNumberFormatter.toPersianDigits(customer.mobile),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
