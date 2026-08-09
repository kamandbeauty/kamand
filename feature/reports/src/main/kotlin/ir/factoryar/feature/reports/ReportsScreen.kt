package ir.factoryar.feature.reports

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.JalaliDatePickerDialog
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.components.ChartSeries
import ir.factoryar.core.ui.components.ComparisonBarChart
import ir.factoryar.core.ui.components.SimpleBarChart
import kotlinx.coroutines.flow.collectLatest

@Composable
fun ReportsScreen(
    onGoPremium: () -> Unit,
    onBack: (() -> Unit)? = null,
    onOpenExpenses: () -> Unit = {},
    viewModel: ReportsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var showFromPicker by remember { mutableStateOf(false) }
    var showToPicker by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.events.collectLatest { e ->
            when (e) {
                is ReportsEvent.Message -> snackbar.showSnackbar(e.text)
                ReportsEvent.PremiumRequired -> onGoPremium()
            }
        }
    }

    Scaffold(
        topBar = { FyTopBar(title = "گزارش‌های مالی", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Row(
                    Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ReportRange.entries.forEach { r ->
                        FilterChip(selected = state.range == r, onClick = { viewModel.setRange(r) }, label = { Text(r.faName) })
                    }
                }
            }
            if (state.range == ReportRange.CUSTOM) {
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { showFromPicker = true }, modifier = Modifier.weight(1f)) {
                            Text("از: ${JalaliConverter.fromEpochMillis(state.customFrom).format().toPersianDigits()}")
                        }
                        OutlinedButton(onClick = { showToPicker = true }, modifier = Modifier.weight(1f)) {
                            Text("تا: ${JalaliConverter.fromEpochMillis(state.customTo).format().toPersianDigits()}")
                        }
                    }
                }
            }

            val report = state.report
            if (state.isLoading || report == null) {
                item {
                    Column(Modifier.fillMaxWidth().padding(48.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator()
                    }
                }
            } else {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f))) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Column(Modifier.weight(1f)) { Text("جمع فروش", style = MaterialTheme.typography.labelMedium); MoneyText(report.totalSales, style = MaterialTheme.typography.titleMedium) }
                                Column(Modifier.weight(1f)) { Text("جمع خرید", style = MaterialTheme.typography.labelMedium); MoneyText(report.totalPurchase, style = MaterialTheme.typography.titleMedium) }
                            }
                            HorizontalDivider()
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Column(Modifier.weight(1f)) { Text("سود ناخالص", style = MaterialTheme.typography.labelMedium); MoneyText(report.grossProfit, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary) }
                                Column(Modifier.weight(1f)) { Text("تعداد فاکتور", style = MaterialTheme.typography.labelMedium); Text(report.invoiceCount.toString().toPersianDigits(), style = MaterialTheme.typography.titleMedium) }
                            }
                        }
                    }
                }
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("وضعیت دریافت", style = MaterialTheme.typography.titleSmall)
                            ReportRow("دریافت‌شده") { MoneyText(report.paidAmount, style = MaterialTheme.typography.bodyMedium) }
                            ReportRow("دریافت‌نشده") { MoneyText(report.unpaidAmount, style = MaterialTheme.typography.bodyMedium) }
                            ReportRow("معوق") { MoneyText(report.overdueAmount, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error) }
                        }
                    }
                }
                // ---------- سود واقعی: فروش − بهای تمام‌شده − هزینه‌ها ----------
                state.profit?.let { profit ->
                    item {
                        Card(
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                            ),
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text("سود واقعی", Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                                    TextButton(onClick = onOpenExpenses) { Text("مدیریت هزینه‌ها") }
                                }
                                ReportRow("درآمد فروش") { MoneyText(profit.revenue, style = MaterialTheme.typography.bodyMedium) }
                                ReportRow("بهای تمام‌شده کالا") { MoneyText(profit.costOfGoodsSold, style = MaterialTheme.typography.bodyMedium) }
                                HorizontalDivider()
                                ReportRow("سود ناخالص") {
                                    MoneyText(
                                        profit.grossProfit,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                                ReportRow("هزینه‌های عمومی") {
                                    MoneyText(
                                        profit.operatingExpenses,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.error,
                                    )
                                }
                                HorizontalDivider()
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text("سود خالص", Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                                    MoneyText(
                                        profit.netProfit,
                                        style = MaterialTheme.typography.titleMedium,
                                        color = if (profit.netProfit >= 0) {
                                            MaterialTheme.colorScheme.primary
                                        } else {
                                            MaterialTheme.colorScheme.error
                                        },
                                    )
                                }
                                if (profit.revenue > 0) {
                                    Text(
                                        "حاشیه سود ناخالص ${PersianFormatter.formatQuantity(profit.grossMarginPercent)}٪ • " +
                                            "حاشیه سود خالص ${PersianFormatter.formatQuantity(profit.netMarginPercent)}٪",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }

                    // نمودار مقایسه‌ای درآمد / هزینه / سود خالص
                    if (profit.series.isNotEmpty()) {
                        item {
                            Card(
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                ),
                            ) {
                                Column(Modifier.padding(14.dp)) {
                                    Text("مقایسه درآمد / هزینه / سود خالص", style = MaterialTheme.typography.titleSmall)
                                    Spacer(Modifier.height(10.dp))
                                    ComparisonBarChart(
                                        labels = profit.series.map { it.label.toPersianDigits() },
                                        series = listOf(
                                            ChartSeries(
                                                label = "درآمد",
                                                color = MaterialTheme.colorScheme.primary,
                                                values = profit.series.map { it.revenue },
                                            ),
                                            ChartSeries(
                                                label = "هزینه",
                                                color = MaterialTheme.colorScheme.error.copy(alpha = 0.8f),
                                                values = profit.series.map { it.cost + it.expenses },
                                            ),
                                            ChartSeries(
                                                label = "سود خالص",
                                                color = MaterialTheme.colorScheme.tertiary,
                                                values = profit.series.map { it.netProfit },
                                            ),
                                        ),
                                    )
                                }
                            }
                        }
                    }

                    // هزینه به تفکیک دسته
                    if (profit.expensesByCategory.isNotEmpty()) {
                        item {
                            Card(
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                ),
                            ) {
                                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text("هزینه‌ها به تفکیک دسته", style = MaterialTheme.typography.titleSmall)
                                    Spacer(Modifier.height(4.dp))
                                    profit.expensesByCategory.take(8).forEach { c ->
                                        ReportRow(c.categoryName) {
                                            MoneyText(c.total, style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if (report.dailySales.isNotEmpty()) {
                    item {
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))) {
                            Column(Modifier.padding(14.dp)) {
                                Text("روند فروش روزانه", style = MaterialTheme.typography.titleSmall)
                                Spacer(Modifier.height(10.dp))
                                val values = report.dailySales.map { (day, total) ->
                                    val d = JalaliConverter.fromEpochMillis(day)
                                    "${d.day.toString().toPersianDigits()}" to total
                                }
                                SimpleBarChart(values = values, highlightLast = false)
                            }
                        }
                    }
                }
            }

            item {
                SectionHeader(title = "خروجی گزارش")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = viewModel::exportCsv, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Filled.FileDownload, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Excel / CSV")
                    }
                    OutlinedButton(onClick = viewModel::exportPdf, modifier = Modifier.weight(1f)) {
                        Icon(if (state.isPremium) Icons.Filled.PictureAsPdf else Icons.Filled.Lock, null)
                        Spacer(Modifier.width(6.dp))
                        Text("PDF حرفه‌ای")
                    }
                }
                if (!state.isPremium) {
                    TextButton(onClick = onGoPremium, modifier = Modifier.fillMaxWidth()) {
                        Text("ارتقا به اشتراک طلایی برای خروجی PDF")
                    }
                }
                Spacer(Modifier.height(48.dp))
            }
        }
    }

    if (showFromPicker) {
        JalaliDatePickerDialog(
            initialMillis = state.customFrom,
            onDismiss = { showFromPicker = false },
            onConfirm = { viewModel.setCustomRange(it, state.customTo); showFromPicker = false },
            title = "از تاریخ",
        )
    }
    if (showToPicker) {
        JalaliDatePickerDialog(
            initialMillis = state.customTo,
            onDismiss = { showToPicker = false },
            onConfirm = { viewModel.setCustomRange(state.customFrom, it); showToPicker = false },
            title = "تا تاریخ",
        )
    }
}

@Composable
private fun ReportRow(label: String, value: @Composable () -> Unit) {
    Row {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        value()
    }
}
