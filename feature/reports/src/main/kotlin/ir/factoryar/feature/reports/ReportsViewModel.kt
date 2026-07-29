package ir.factoryar.feature.reports

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.domain.model.ProfitReport
import ir.factoryar.core.domain.model.SalesReport
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.usecase.BuildProfitReportUseCase
import ir.factoryar.core.domain.usecase.BuildSalesReportUseCase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject

enum class ReportRange(val faName: String) {
    TODAY("امروز"),
    LAST_7_DAYS("۷ روز اخیر"),
    THIS_MONTH("این ماه"),
    CUSTOM("بازه دلخواه"),
}

data class ReportsUiState(
    val range: ReportRange = ReportRange.THIS_MONTH,
    val customFrom: Long = DateUtils.startOfMonthJalali(),
    val customTo: Long = DateUtils.plusDays(DateUtils.startOfToday(), 1),
    val report: SalesReport? = null,
    /** گزارش سود واقعی (شامل بهای تمام‌شده و هزینه‌های عمومی) */
    val profit: ProfitReport? = null,
    val isPremium: Boolean = false,
    val isLoading: Boolean = true,
) {
    fun effectiveRange(): Pair<Long, Long> = when (range) {
        ReportRange.TODAY -> DateUtils.startOfToday() to DateUtils.plusDays(DateUtils.startOfToday(), 1)
        ReportRange.LAST_7_DAYS -> DateUtils.daysAgo(6) to DateUtils.plusDays(DateUtils.startOfToday(), 1)
        ReportRange.THIS_MONTH -> DateUtils.startOfMonthJalali() to DateUtils.plusDays(DateUtils.startOfToday(), 1)
        ReportRange.CUSTOM -> customFrom to customTo
    }
}

sealed interface ReportsEvent {
    data class Message(val text: String) : ReportsEvent
    data object PremiumRequired : ReportsEvent
}

@HiltViewModel
class ReportsViewModel @Inject constructor(
    private val buildReport: BuildSalesReportUseCase,
    private val buildProfitReport: BuildProfitReportUseCase,
    settingsRepository: SettingsRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val filter = MutableStateFlow(ReportsUiState())
    private val report = MutableStateFlow<SalesReport?>(null)
    private val profit = MutableStateFlow<ProfitReport?>(null)
    private val loading = MutableStateFlow(true)

    val isPremium: StateFlow<Boolean> = settingsRepository.settings
        .map { it.isPremium }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    val uiState: StateFlow<ReportsUiState> =
        combine(filter, report, profit, loading, isPremium) { f, r, pr, l, p ->
            f.copy(report = r, profit = pr, isLoading = l, isPremium = p)
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReportsUiState())

    private val _events = MutableSharedFlow<ReportsEvent>()
    val events: SharedFlow<ReportsEvent> = _events

    init {
        viewModelScope.launch {
            filter.map { it.effectiveRange() }.collect { (from, to) ->
                loading.value = true
                report.value = buildReport(from, to)
                profit.value = buildProfitReport(from, to)
                loading.value = false
            }
        }
    }

    fun setRange(range: ReportRange) {
        filter.value = filter.value.copy(range = range)
    }

    fun setCustomRange(from: Long, to: Long) {
        filter.value = filter.value.copy(range = ReportRange.CUSTOM, customFrom = from, customTo = to)
    }

    /** خروجی CSV (رایگان) با BOM برای نمایش درست فارسی در اکسل */
    fun exportCsv() {
        val r = report.value ?: return
        viewModelScope.launch {
            runCatching {
                val file = withContext(Dispatchers.IO) { writeCsvFile(r) }
                shareFile(file, "text/csv", "گزارش فروش")
            }.onFailure { _events.emit(ReportsEvent.Message("خطا در خروجی: ${it.message}")) }
        }
    }

    /** خروجی PDF گزارش — فقط اشتراک طلایی */
    fun exportPdf() {
        val r = report.value ?: return
        if (!isPremium.value) {
            viewModelScope.launch { _events.emit(ReportsEvent.PremiumRequired) }
            return
        }
        viewModelScope.launch {
            runCatching {
                val file = withContext(Dispatchers.IO) {
                    ir.factoryar.core.pdf.ReportPdfGenerator(context).generate(r)
                }
                shareFile(file, "application/pdf", "گزارش فروش PDF")
            }.onFailure { _events.emit(ReportsEvent.Message("خطا در ساخت PDF: ${it.message}")) }
        }
    }

    private fun writeCsvFile(r: SalesReport): File {
        val from = JalaliConverter.fromEpochMillis(r.from).format()
        val to = JalaliConverter.fromEpochMillis(r.to).format()
        val sb = StringBuilder()
        sb.append("﻿") // BOM برای اکسل
        sb.appendLine("گزارش فروش فاکتوریار")
        sb.appendLine("از تاریخ,$from,تا تاریخ,$to")
        sb.appendLine()
        sb.appendLine("شاخص,مقدار (به واحد پول تنظیم‌شده)")
        sb.appendLine("تعداد فاکتور فروش,${r.invoiceCount}")
        sb.appendLine("جمع فروش,${r.totalSales}")
        sb.appendLine("جمع خرید,${r.totalPurchase}")
        sb.appendLine("سود ناخالص (فروش − خرید),${r.grossProfit}")
        sb.appendLine("دریافت‌شده,${r.paidAmount}")
        sb.appendLine("دریافت‌نشده,${r.unpaidAmount}")
        sb.appendLine("مبالغ معوق,${r.overdueAmount}")
        sb.appendLine()
        profit.value?.let { p ->
            sb.appendLine("تحلیل سود واقعی")
            sb.appendLine("درآمد,${p.revenue}")
            sb.appendLine("بهای تمام‌شده کالای فروش‌رفته,${p.costOfGoodsSold}")
            sb.appendLine("سود ناخالص,${p.grossProfit}")
            sb.appendLine("هزینه‌های عمومی,${p.operatingExpenses}")
            sb.appendLine("سود خالص,${p.netProfit}")
            sb.appendLine()
            if (p.expensesByCategory.isNotEmpty()) {
                sb.appendLine("دسته هزینه,مبلغ,تعداد")
                p.expensesByCategory.forEach { c ->
                    sb.appendLine("${c.categoryName},${c.total},${c.count}")
                }
                sb.appendLine()
            }
        }
        sb.appendLine("تاریخ,فروش روزانه")
        r.dailySales.forEach { (day, total) ->
            sb.appendLine("${JalaliConverter.fromEpochMillis(day).format()},$total")
        }
        val dir = File(context.getExternalFilesDir(null) ?: context.filesDir, "reports").apply { mkdirs() }
        val file = File(dir, "sales_report_${System.currentTimeMillis()}.csv")
        file.writeText(sb.toString(), Charsets.UTF_8)
        return file
    }

    private fun shareFile(file: File, mime: String, title: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(shareIntent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
