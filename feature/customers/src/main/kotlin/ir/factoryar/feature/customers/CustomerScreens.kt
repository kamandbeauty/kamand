package ir.factoryar.feature.customers

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.MoneyOff
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.CustomerWithBalance
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip
import ir.factoryar.core.ui.components.SearchField
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.components.StatCard

@Composable
fun CustomersScreen(
    onCustomerClick: (Long) -> Unit,
    onBack: (() -> Unit)? = null,
    onOpenDebtors: () -> Unit = {},
    viewModel: CustomersViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<Customer?>(null) }
    var showEditor by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            FyTopBar(
                title = "مشتریان",
                onBack = onBack,
                actions = {
                    IconButton(onClick = onOpenDebtors) {
                        Icon(Icons.Filled.MoneyOff, contentDescription = "بدهکاران")
                    }
                },
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { editing = null; showEditor = true },
                icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                text = { Text("مشتری جدید") },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            SearchField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                placeholder = "جستجوی نام یا شماره تماس…",
            )
            if (state.isEmpty) {
                EmptyState(
                    icon = Icons.Filled.Person,
                    title = if (state.query.isBlank()) "هنوز مشتری‌ای ثبت نشده" else "موردی یافت نشد",
                    description = "برای صدور فاکتور، اول مشتری بسازید یا هنگام صدور سریع ثبت کنید.",
                    modifier = Modifier.weight(1f),
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.customers, key = { it.customer.id }) { row ->
                        CustomerRow(row = row, onClick = { onCustomerClick(row.customer.id) })
                    }
                    item { Spacer(Modifier.height(72.dp)) }
                }
            }
        }
    }

    if (showEditor) {
        CustomerEditorDialog(
            initial = editing,
            onDismiss = { showEditor = false },
            onSave = { customer -> viewModel.save(customer) { showEditor = false } },
        )
    }
}

@Composable
private fun CustomerRow(row: CustomerWithBalance, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
                modifier = Modifier.size(44.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        row.customer.name.take(1),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(row.customer.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (row.customer.phone.isNotBlank()) {
                    Text(row.customer.phone.toPersianDigits(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                if (row.totalDebt > 0) {
                    MoneyText(row.totalDebt, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.error)
                    if (row.hasOverdue) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Warning, contentDescription = "معوق", modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.error)
                            Text(" معوق", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                        }
                    }
                } else {
                    Text("بدون بدهی", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

/** دیالوگ ثبت/ویرایش مشتری — هم در لیست و هم حین صدور فاکتور استفاده می‌شود */
@Composable
fun CustomerEditorDialog(
    initial: Customer?,
    onDismiss: () -> Unit,
    onSave: (Customer) -> Unit,
) {
    var name by remember { mutableStateOf(initial?.name.orEmpty()) }
    var phone by remember { mutableStateOf(initial?.phone.orEmpty()) }
    var email by remember { mutableStateOf(initial?.email.orEmpty()) }
    var address by remember { mutableStateOf(initial?.address.orEmpty()) }
    var note by remember { mutableStateOf(initial?.note.orEmpty()) }
    var error by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "مشتری جدید" else "ویرایش مشتری") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name, onValueChange = { name = it; error = null },
                    label = { Text("نام و نام خانوادگی *") }, singleLine = true,
                    isError = error != null, modifier = Modifier.fillMaxWidth(),
                )
                if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall)
                OutlinedTextField(value = phone, onValueChange = { phone = it }, label = { Text("شماره تماس") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("ایمیل") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = address, onValueChange = { address = it }, label = { Text("آدرس") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("یادداشت") }, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = {
            Button(onClick = {
                if (name.isBlank()) { error = "نام مشتری الزامی است"; return@Button }
                onSave(
                    Customer(
                        id = initial?.id ?: 0,
                        name = name.trim(), phone = phone.trim(), email = email.trim(),
                        address = address.trim(), note = note.trim(),
                        createdAt = initial?.createdAt ?: 0,
                    ),
                )
            }) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
