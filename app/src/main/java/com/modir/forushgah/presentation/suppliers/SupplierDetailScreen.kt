package com.modir.forushgah.presentation.suppliers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.designsystem.component.EmptyState

@Composable
fun SupplierDetailRoute(
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onArchived: () -> Unit,
    viewModel: SupplierDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var showArchiveConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(event) {
        when (val e = event) {
            SupplierDetailEvent.Archived -> onArchived()
            is SupplierDetailEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    SupplierDetailScreen(
        state = state,
        showArchiveConfirm = showArchiveConfirm,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onEdit = onEdit,
        onArchiveClick = { showArchiveConfirm = true },
        onArchiveConfirmed = viewModel::archiveSupplier,
        onArchiveDismiss = { showArchiveConfirm = false },
    )
}

@Composable
fun SupplierDetailScreen(
    state: SupplierDetailUiState,
    showArchiveConfirm: Boolean,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onArchiveClick: () -> Unit,
    onArchiveConfirmed: () -> Unit,
    onArchiveDismiss: () -> Unit,
) {
    val profile = state.profile
    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("تأمین‌کننده") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
                actions = {
                    if (profile != null) {
                        IconButton(onClick = onEdit) {
                            Icon(Icons.Filled.Edit, contentDescription = "ویرایش")
                        }
                        IconButton(onClick = onArchiveClick) {
                            Icon(Icons.Filled.Archive, contentDescription = "بایگانی")
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
                    title = "تأمین‌کننده یافت نشد",
                    subtitle = "این تأمین‌کننده دیگر در دسترس نیست",
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
                            Text(profile.supplier.name, style = MaterialTheme.typography.titleLarge)
                            DetailRow("تلفن", profile.supplier.phone)
                            DetailRow("آدرس", profile.supplier.address)
                            DetailRow("یادداشت", profile.supplier.notes)
                        }
                    }
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("آمار مالی", style = MaterialTheme.typography.titleMedium)
                            MoneyRow("خرید کل", profile.totalPurchased)
                            MoneyRow("پرداختی‌ها", profile.totalPaid)
                            MoneyRow("بدهی باز", profile.outstandingDebt)
                            Text(
                                "اعداد با فعال‌شدن موتور مالی (فاز ۴/۵) به‌روز می‌شوند",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("تاریخچه خرید", style = MaterialTheme.typography.titleMedium)
                            Text(
                                "هنوز خریدی ثبت نشده است",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("تاریخچه پرداخت", style = MaterialTheme.typography.titleMedium)
                            Text(
                                "هنوز پرداختی ثبت نشده است",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }

    if (showArchiveConfirm && profile != null) {
        AlertDialog(
            onDismissRequest = onArchiveDismiss,
            title = { Text("بایگانی تأمین‌کننده") },
            text = {
                Text("«${profile.supplier.name}» بایگانی می‌شود و دیگر در لیست تأمین‌کنندگان نمایش داده نمی‌شود.")
            },
            confirmButton = { TextButton(onClick = onArchiveConfirmed) { Text("بایگانی") } },
            dismissButton = { TextButton(onClick = onArchiveDismiss) { Text("انصراف") } },
        )
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

@Composable
private fun MoneyRow(label: String, value: com.modir.forushgah.core.common.Money) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            value.toPersianDisplayString(),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
