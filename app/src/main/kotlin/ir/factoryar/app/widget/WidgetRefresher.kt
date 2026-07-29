package ir.factoryar.app.widget

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.FlowPreview
import javax.inject.Inject
import javax.inject.Singleton

/**
 * ویجت را هنگام تغییر داده‌های مالی یا تم به‌روزرسانی می‌کند
 * تا کاربر همیشه فروش امروز و تعداد معوق‌ها را درست ببیند.
 */
@Singleton
class WidgetRefresher @Inject constructor(
    @ApplicationContext private val context: Context,
    private val invoiceRepository: InvoiceRepository,
    private val settingsRepository: SettingsRepository,
) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @OptIn(FlowPreview::class)
    fun start() {
        combine(
            invoiceRepository.observeDashboardSummary()
                .map { Triple(it.todaySales, it.todayInvoiceCount, it.overdueCount) },
            settingsRepository.settings.map { it.themePreset to it.themeMode },
        ) { financial, theme -> financial to theme }
            .distinctUntilChanged()
            .debounce(500)
            .drop(1) // مقدار اولیه لازم نیست ویجت را به‌روز کند
            .onEach {
                if (WidgetDataLoader.hasWidgets(context)) {
                    WidgetDataLoader.refreshAll(context)
                }
            }
            .launchIn(scope)
    }
}
