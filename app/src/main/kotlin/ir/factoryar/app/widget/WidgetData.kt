package ir.factoryar.app.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.jalali.JalaliDate
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.repository.BusinessRepository
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.repository.ThemeMode
import ir.factoryar.core.domain.repository.ThemePreset
import kotlinx.coroutines.flow.first

/** داده‌ای که ویجت نمایش می‌دهد */
data class WidgetData(
    val businessName: String = "",
    val todayLabel: String = "",
    val todaySalesLabel: String = "۰",
    val todayInvoiceCount: Int = 0,
    val overdueCount: Int = 0,
    /** رنگ اصلی تم انتخابی کاربر */
    val primaryArgb: Long = 0xFF1E5AA8,
    val dark: Boolean = false,
)

/** دسترسی به Repositoryها از داخل Glance (که ViewModel ندارد) */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface WidgetEntryPoint {
    fun invoiceRepository(): InvoiceRepository
    fun settingsRepository(): SettingsRepository
    fun businessRepository(): BusinessRepository
}

object WidgetDataLoader {

    suspend fun load(context: Context): WidgetData {
        val entryPoint = EntryPointAccessors.fromApplication(
            context.applicationContext,
            WidgetEntryPoint::class.java,
        )
        return runCatching {
            val settings = entryPoint.settingsRepository().settings.first()
            val summary = entryPoint.invoiceRepository().observeDashboardSummary().first()
            val profile = entryPoint.businessRepository().observeActiveProfile().first()

            val today = JalaliConverter.today()
            val unit = CurrencyUnit.fromName(settings.currencyUnit)
            val seed = when (settings.themePreset) {
                ThemePreset.CLASSIC_BLUE -> 0xFF1E5AA8
                ThemePreset.FINANCE_GREEN -> 0xFF0E7A4F
                ThemePreset.MODERN_PURPLE -> 0xFF6D4BC0
                ThemePreset.WARM_ORANGE -> 0xFFD96A1F
                ThemePreset.MINIMAL_GRAY -> 0xFF54606E
                ThemePreset.CUSTOM -> settings.customPrimaryColor
            }

            WidgetData(
                businessName = profile?.name.orEmpty(),
                todayLabel = "${today.day.toString().toPersianDigits()} ${JalaliDate.monthName(today.month)}",
                todaySalesLabel = PersianFormatter.formatMoneyWithUnit(summary.todaySales, unit),
                todayInvoiceCount = summary.todayInvoiceCount,
                overdueCount = summary.overdueCount,
                primaryArgb = seed,
                dark = when (settings.themeMode) {
                    ThemeMode.DARK -> true
                    ThemeMode.LIGHT -> false
                    ThemeMode.SYSTEM -> context.isSystemDark()
                },
            )
        }.getOrDefault(WidgetData())
    }

    /** به‌روزرسانی همه نمونه‌های ویجت — پس از ذخیره فاکتور/تغییر تم صدا زده می‌شود */
    suspend fun refreshAll(context: Context) {
        runCatching {
            FactorYarWidget().updateAll(context)
        }
    }

    /** آیا اصلاً ویجتی روی صفحه اصلی نصب شده است؟ (برای صرفه‌جویی در کار) */
    suspend fun hasWidgets(context: Context): Boolean = runCatching {
        GlanceAppWidgetManager(context).getGlanceIds(FactorYarWidget::class.java).isNotEmpty()
    }.getOrDefault(false)
}

private fun Context.isSystemDark(): Boolean =
    (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
        android.content.res.Configuration.UI_MODE_NIGHT_YES
