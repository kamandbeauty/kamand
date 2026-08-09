package ir.factoryar.core.domain.repository

import ir.factoryar.core.domain.model.InvoiceType
import kotlinx.coroutines.flow.Flow

enum class ThemeMode { SYSTEM, LIGHT, DARK }

enum class ThemePreset(val faName: String) {
    CLASSIC_BLUE("آبی کلاسیک"),
    FINANCE_GREEN("سبز مالی"),
    MODERN_PURPLE("بنفش مدرن"),
    WARM_ORANGE("نارنجی گرم"),
    MINIMAL_GRAY("خاکستری مینیمال"),
    CUSTOM("رنگ دلخواه");

    companion object {
        fun fromName(name: String?): ThemePreset = entries.firstOrNull { it.name == name } ?: CLASSIC_BLUE
    }
}

/** تنظیمات کلی اپ — منبع: DataStore */
data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val themePreset: ThemePreset = ThemePreset.CLASSIC_BLUE,
    /** رنگ اصلی سفارشی (ARGB) — اشتراک طلایی */
    val customPrimaryColor: Long = 0xFF1E5AA8,
    val currencyUnit: String = "TOMAN",
    val defaultTaxPercent: Double = 10.0,
    val defaultTerms: String = "",
    val invoicePrefixes: Map<InvoiceType, String> = InvoiceType.entries.associateWith { it.defaultPrefix },
    /** نمایش لوگو/امضا/شرایط روی خروجی PDF و تصویر */
    val printShowLogo: Boolean = true,
    val printShowSignature: Boolean = true,
    val printShowTerms: Boolean = true,
    val weeklyBackupEnabled: Boolean = false,
    val isPremium: Boolean = false,
)

interface SettingsRepository {
    val settings: Flow<AppSettings>

    suspend fun setThemeMode(mode: ThemeMode)
    suspend fun setThemePreset(preset: ThemePreset)
    suspend fun setCustomPrimaryColor(argb: Long)
    suspend fun setCurrencyUnit(unit: String)
    suspend fun setDefaultTaxPercent(percent: Double)
    suspend fun setDefaultTerms(terms: String)
    suspend fun setInvoicePrefix(type: InvoiceType, prefix: String)
    /** شماره بعدی + افزایش شمارنده (در تراکنش ذخیره فاکتور صدا زده می‌شود) */
    suspend fun consumeNextNumber(type: InvoiceType): String
    suspend fun previewNextNumber(type: InvoiceType): String
    suspend fun setNextNumber(type: InvoiceType, next: Long)
    suspend fun setPrintFlags(showLogo: Boolean, showSignature: Boolean, showTerms: Boolean)
    suspend fun setWeeklyBackupEnabled(enabled: Boolean)
    suspend fun setPremium(value: Boolean)
}
