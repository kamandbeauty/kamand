package ir.factoryar.feature.dashboard

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.PaymentStatusChip
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.components.SimpleBarChart
import ir.factoryar.core.ui.components.StatCard

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
    val today = JalaliConverter.today()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "${ir.factoryar.core.common.jalali.JalaliDate.WEEKDAY_NAMES[JalaliConverter.weekdayOf(today)]}، ${today.day.toString().toPersianDigits()} ${ir.factoryar.core.common.jalali.JalaliDate.monthName(today.month)}",
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
        }

        item {
            Button(onClick = onNewInvoice, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Icon(Icons.Filled.Receipt, null)
                Spacer(Modifier.width(8.dp))
                Text("صدور فاکتور جدید", style = MaterialTheme.typography.titleMedium)
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(onClick = onNewCustomer, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.People, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("مشتری", style = MaterialTheme.typography.labelLarge)
                }
                FilledTonalButton(onClick = onOpenProducts, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.Inventory2, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("انبار", style = MaterialTheme.typography.labelLarge)
                }
                FilledTonalButton(onClick = onOpenExpenses, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.ReceiptLong, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("هزینه", style = MaterialTheme.typography.labelLarge)
                }
            }
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MoneyStatCard("فروش امروز", state.summary.todaySales, Modifier.weight(1f), Icons.Filled.AttachMoney, "${state.summary.todayInvoiceCount} فاکتور".toPersianDigits())
                MoneyStatCard("فروش این ماه", state.summary.monthSales, Modifier.weight(1f), Icons.Filled.CalendarMonth)
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    title = "طلب از مشتریان",
                    value = PersianFormatter.formatMoney(state.summary.totalReceivable),
                    icon = Icons.Filled.TrendingUp,
                    modifier = Modifier.weight(1f),
                    onClick = onOpenDebtors,
                )
                StatCard(
                    title = "فاکتور معوق",
                    value = state.summary.overdueCount.toString().toPersianDigits(),
                    icon = Icons.Filled.Warning,
                    modifier = Modifier.weight(1f),
                    containerColor = if (state.summary.overdueCount > 0) MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f) else MaterialTheme.colorScheme.surfaceVariant,
                    onClick = onOpenDebtors,
                )
            }
            Spacer(Modifier.height(10.dp))
            // سود خالص و هزینه‌های این ماه
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    title = "سود خالص این ماه",
                    value = PersianFormatter.formatMoney(state.summary.monthNetProfit),
                    icon = Icons.Filled.Savings,
                    modifier = Modifier.weight(1f),
                    valueColor = if (state.summary.monthNetProfit >= 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    subtitle = "فروش − بهای تمام‌شده − هزینه",
                    onClick = onOpenExpenses,
                )
                StatCard(
                    title = "هزینه‌های این ماه",
                    value = PersianFormatter.formatMoney(state.summary.monthExpenses),
                    icon = Icons.Filled.ReceiptLong,
                    modifier = Modifier.weight(1f),
                    onClick = onOpenExpenses,
                )
            }
            Spacer(Modifier.height(10.dp))
            // وضعیت انبار
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    title = "ارزش انبار",
                    value = PersianFormatter.formatMoney(state.summary.inventory.totalStockValue),
                    icon = Icons.Filled.Inventory2,
                    modifier = Modifier.weight(1f),
                    subtitle = "${state.summary.inventory.productCount.toString().toPersianDigits()} کالا",
                    onClick = onOpenProducts,
                )
                StatCard(
                    title = "رو به اتمام",
                    value = state.summary.inventory.lowStockCount.toString().toPersianDigits(),
                    icon = Icons.Filled.Warning,
                    modifier = Modifier.weight(1f),
                    containerColor = if (state.summary.inventory.lowStockCount > 0) MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f) else MaterialTheme.colorScheme.surfaceVariant,
                    onClick = onOpenProducts,
                )
            }
        }

        // کالاهای بحرانی
        if (state.summary.inventory.criticalProducts.isNotEmpty()) {
            item { SectionHeader(title = "کالاهای رو به اتمام") }
            state.summary.inventory.criticalProducts.forEach { product ->
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable { onOpenProducts() },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f)),
                    ) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Inventory2, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.error)
                            Spacer(Modifier.width(8.dp))
                            Text(product.name, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(
                                "${PersianFormatter.formatQuantity(product.stockQuantity)} ${product.unit}",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))) {
                Column(Modifier.padding(14.dp)) {
                    Text("فروش ۷ روز اخیر", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(10.dp))
                    val values = state.summary.last7DaysSales.map { (dayMillis, total) ->
                        val d = JalaliConverter.fromEpochMillis(dayMillis)
                        "${d.day.toString().toPersianDigits()} ${ir.factoryar.core.common.jalali.JalaliDate.monthName(d.month).take(3)}" to total
                    }
                    SimpleBarChart(values = values)
                }
            }
        }

        if (state.topDebtors.isNotEmpty()) {
            item { SectionHeader(title = "بیشترین بدهکاران") }
            state.topDebtors.forEach { debtor ->
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable { onCustomerClick(debtor.customer.id) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    ) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(debtor.customer.name, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (debtor.hasOverdue) Icon(Icons.Filled.Warning, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.error)
                            Spacer(Modifier.width(6.dp))
                            MoneyText(debtor.totalDebt, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            }
        }

        item {
            SectionHeader(title = "فاکتورهای اخیر") {
                Text(state.recentInvoices.size.toString().toPersianDigits(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        state.recentInvoices.forEach { details ->
            item {
                Row(
                    Modifier.fillMaxWidth().clickable { onInvoiceClick(details.invoice.id) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Surface(shape = CircleShape, color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), modifier = Modifier.size(38.dp)) {
                        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Filled.Receipt, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(details.invoice.number.toPersianDigits(), style = MaterialTheme.typography.bodyMedium)
                        Text(details.customer?.name ?: "—", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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

@Composable
private fun MoneyStatCard(
    title: String,
    amount: Long,
    modifier: Modifier = Modifier,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    subtitle: String? = null,
) {
    Card(modifier = modifier, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(6.dp))
                Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.height(8.dp))
            MoneyText(amount, style = MaterialTheme.typography.titleMedium)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
