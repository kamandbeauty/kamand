package ir.factoryar.feature.customers

import android.content.Context
import android.content.Intent
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText

/**
 * فهرست مشتریان بدهکار + تولید و ارسال متن یادآوری.
 * ارسال از طریق Share Intent استاندارد انجام می‌شود (پیامک، واتساپ، تلگرام و…)
 */
@Composable
fun DebtorsScreen(
    onBack: () -> Unit,
    onCustomerClick: (Long) -> Unit,
    viewModel: DebtorsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var reminderFor by remember { mutableStateOf<DebtorEntry?>(null) }
    var reminderText by remember { mutableStateOf("") }

    Scaffold(
        topBar = { FyTopBar(title = "بدهکاران", onBack = onBack) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Card(
                        Modifier.weight(1f),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        ),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text(
                                "کل مطالبات",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(Modifier.height(6.dp))
                            MoneyText(state.summary.totalDebt, style = MaterialTheme.typography.titleMedium)
                        }
                    }
                    Card(
                        Modifier.weight(1f),
                        colors = CardDefaults.cardColors(
                            containerColor = if (state.summary.totalOverdue > 0) {
                                MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f)
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                        ),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text(
                                "معوق (سررسید گذشته)",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(Modifier.height(6.dp))
                            MoneyText(
                                state.summary.totalOverdue,
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }

            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(DebtorSort.entries.toList()) { s ->
                        FilterChip(
                            selected = state.sort == s,
                            onClick = { viewModel.setSort(s) },
                            label = { Text(s.faName, style = MaterialTheme.typography.labelMedium) },
                        )
                    }
                    item {
                        FilterChip(
                            selected = state.onlyOverdue,
                            onClick = { viewModel.toggleOnlyOverdue() },
                            label = { Text("فقط معوق", style = MaterialTheme.typography.labelMedium) },
                        )
                    }
                }
            }

            if (state.summary.debtors.isEmpty() && !state.isLoading) {
                item {
                    EmptyState(
                        icon = Icons.Filled.CheckCircle,
                        title = "بدهکاری ندارید!",
                        description = "همه فاکتورهای فروش تسویه شده‌اند.",
                        modifier = Modifier.height(320.dp),
                    )
                }
            }

            items(state.summary.debtors, key = { it.customer.id }) { entry ->
                DebtorCard(
                    entry = entry,
                    onClick = { onCustomerClick(entry.customer.id) },
                    onRemind = {
                        viewModel.buildReminder(entry) { text ->
                            reminderText = text
                            reminderFor = entry
                        }
                    },
                )
            }
        }
    }

    reminderFor?.let { entry ->
        ReminderDialog(
            entry = entry,
            text = reminderText,
            onTextChange = { reminderText = it },
            onDismiss = { reminderFor = null },
            onShare = {
                context.shareText(reminderText)
                reminderFor = null
            },
            onSms = {
                context.sendSms(entry.customer.phone, reminderText)
                reminderFor = null
            },
        )
    }
}

@Composable
private fun DebtorCard(
    entry: DebtorEntry,
    onClick: () -> Unit,
    onRemind: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (entry.hasOverdue) {
                MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f)
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
            },
        ),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(
                Modifier.fillMaxWidth().clickable(onClick = onClick),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        entry.customer.name,
                        style = MaterialTheme.typography.bodyLarge,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (entry.customer.phone.isNotBlank()) {
                        Text(
                            entry.customer.phone.toPersianDigits(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    MoneyText(
                        entry.totalDebt,
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                    if (entry.hasOverdue) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Filled.Warning,
                                null,
                                Modifier.size(12.dp),
                                tint = MaterialTheme.colorScheme.error,
                            )
                            Spacer(Modifier.width(4.dp))
                            Text(
                                "${entry.maxOverdueDays.toString().toPersianDigits()} روز تأخیر • " +
                                    "${entry.overdueInvoiceCount.toString().toPersianDigits()} فاکتور",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(
                    onClick = onRemind,
                    label = { Text("ارسال یادآوری") },
                    leadingIcon = { Icon(Icons.AutoMirrored.Filled.Send, null, Modifier.size(16.dp)) },
                )
            }
        }
    }
}

@Composable
private fun ReminderDialog(
    entry: DebtorEntry,
    text: String,
    onTextChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onShare: () -> Unit,
    onSms: () -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("یادآوری بدهی — ${entry.customer.name}") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "متن زیر آماده ارسال است؛ در صورت نیاز ویرایش کنید.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = text,
                    onValueChange = onTextChange,
                    modifier = Modifier.fillMaxWidth().height(220.dp),
                    textStyle = MaterialTheme.typography.bodySmall,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(
                        onClick = { clipboard.setText(AnnotatedString(text)) },
                        label = { Text("کپی") },
                        leadingIcon = { Icon(Icons.Filled.ContentCopy, null, Modifier.size(16.dp)) },
                    )
                    if (entry.customer.phone.isNotBlank()) {
                        AssistChip(
                            onClick = onSms,
                            label = { Text("پیامک") },
                            leadingIcon = { Icon(Icons.Filled.Phone, null, Modifier.size(16.dp)) },
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onShare) {
                Icon(Icons.AutoMirrored.Filled.Send, null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("ارسال (واتساپ/تلگرام/…)")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("بستن") } },
    )
}

/** ارسال با Share Intent استاندارد — بدون نیاز به هیچ سرور یا SDK خارجی */
private fun Context.shareText(text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    startActivity(Intent.createChooser(intent, "ارسال یادآوری از طریق").apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    })
}

/** باز کردن مستقیم اپ پیامک با شماره مشتری */
private fun Context.sendSms(phone: String, text: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_SENDTO, android.net.Uri.parse("smsto:${phone.trim()}")).apply {
            putExtra("sms_body", text)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }.onFailure { shareText(text) }
}
