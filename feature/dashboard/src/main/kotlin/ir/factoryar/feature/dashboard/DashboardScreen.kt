package ir.factoryar.feature.dashboard

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip

/**
 * داشبورد ساده‌شده.
 *
 * فلسفهٔ چیدمان: کاربر در ۹۰٪ مواقع فقط می‌خواهد «فاکتور جدید بزند» یا
 * «فاکتور اخیر را ببیند». پس صفحهٔ اصلی همین دو کار را برجسته می‌کند و
 * بقیهٔ آمار (سود، هزینه، انبار) پشت یک بخش جمع‌شونده پنهان است.
 */
@Composable
fun DashboardScreen(
    onNewInvoice: () -> Unit,
    onNewCustomer: () -> Unit,
    onInvoiceClick: (Long) -> Unit,
    onCustomerClick: (Long) -> Unit,
    onSeeAllInvoices: () -> Unit,
    onOpenProducts: () -> Unit = {},
    onOpenExpenses: () -> Unit = {},
    onOpenDebtors: () -> Unit = {},
    viewModel: DashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showMoreStats by remember { mutableStateOf(false) }
    val today = JalaliConverter.today()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // ── سربرگ ────────────────────────────────────────────────────────
        item {
            Column {
                Text(
                    "${JalaliDate.WEEKDAY_NAMES[JalaliConverter.weekdayOf(today)]}، " +
                        "${today.day.toString().toPersianDigits()} ${JalaliDate.monthName(today.month)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    state.businessName.ifBlank { "سلام 👋" },
                    style = MaterialTheme.typography.headlineSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // ── کارت اصلی: فروش امروز ────────────────────────────────────────
        item {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
                ),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(18.dp)) {
                    Text(
                        "فروش امروز",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(6.dp))
                    MoneyText(
                        state.summary.todaySales,
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${state.summary.todayInvoiceCount.toString().toPersianDigits()} فاکتور امروز",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        // ── تنها کار اصلی صفحه ───────────────────────────────────────────
        item {
            Button(
                onClick = onNewInvoice,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
            ) {
                Icon(Icons.Filled.Add, null)
                Spacer(Modifier.width(8.dp))
                Text("فاکتور جدید", style = MaterialTheme.typography.titleMedium)
            }
        }

        // ── هشدار معوقات: فقط وقتی واقعاً وجود دارد ──────────────────────
        if (state.summary.overdueCount > 0) {
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onOpenDebtors),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f),
                    ),
                ) {
                    Row(
                        Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Filled.Warning,
                            null,
                            Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                "${state.summary.overdueCount.toString().toPersianDigits()} فاکتور معوق",
                                style = MaterialTheme.typography.titleSmall,
                            )
                            Text(
                                "پیگیری بدهی مشتریان",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        MoneyText(
                            state.summary.totalReceivable,
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }
        }

        // ── آمار بیشتر: پیش‌فرض بسته ─────────────────────────────────────
        item {
            TextButton(
                onClick = { showMoreStats = !showMoreStats },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (showMoreStats) "بستن آمار" else "آمار بیشتر")
                Spacer(Modifier.width(4.dp))
                Icon(
                    if (showMoreStats) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        item {
            AnimatedVisibility(visible = showMoreStats) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatRow(
                        label = "فروش این ماه",
                        value = PersianFormatter.formatMoney(state.summary.monthSales),
                    )
                    StatRow(
                        label = "سود خالص این ماه",
                        value = PersianFormatter.formatMoney(state.summary.monthNetProfit),
                        valueColor = if (state.summary.monthNetProfit >= 0) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.error
                        },
                        onClick = onOpenExpenses,
                    )
                    StatRow(
                        label = "هزینه‌های این ماه",
                        value = PersianFormatter.formatMoney(state.summary.monthExpenses),
                        onClick = onOpenExpenses,
                    )
                    StatRow(
                        label = "ارزش انبار",
                        value = PersianFormatter.formatMoney(state.summary.inventory.totalStockValue),
                        onClick = onOpenProducts,
                    )
                    if (state.summary.inventory.lowStockCount > 0) {
                        StatRow(
                            label = "کالای رو به اتمام",
                            value = state.summary.inventory.lowStockCount.toString().toPersianDigits(),
                            valueColor = MaterialTheme.colorScheme.error,
                            onClick = onOpenProducts,
                        )
                    }
                }
            }
        }

        // ── فاکتورهای اخیر ───────────────────────────────────────────────
        if (state.recentInvoices.isNotEmpty()) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "فاکتورهای اخیر",
                        Modifier.weight(1f),
                        style = MaterialTheme.typography.titleMedium,
                    )
                    TextButton(onClick = onSeeAllInvoices) { Text("همه") }
                }
            }
            items(state.recentInvoices, key = { it.invoice.id }) { details ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onInvoiceClick(details.invoice.id) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        modifier = Modifier.size(38.dp),
                    ) {
                        Column(
                            Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(
                                Icons.Filled.Receipt,
                                null,
                                Modifier.size(18.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            details.customer?.name ?: details.invoice.number.toPersianDigits(),
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            details.invoice.number.toPersianDigits(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        MoneyText(details.invoice.grandTotal, style = MaterialTheme.typography.bodyMedium)
                        PaymentStatusChip(details.invoice)
                    }
                }
            }
        }

        item { Spacer(Modifier.height(60.dp)) }
    }
}

/** یک سطر آمار ساده — به‌جای کارت‌های بزرگ رنگی */
@Composable
private fun StatRow(
    label: String,
    value: String,
    valueColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(value, style = MaterialTheme.typography.titleSmall, color = valueColor)
    }
}
