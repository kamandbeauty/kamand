package ir.factoryar.core.data.repository

import ir.factoryar.core.datastore.SettingsDataStore
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.repository.AppSettings
import ir.factoryar.core.domain.repository.PremiumRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.repository.ThemeMode
import ir.factoryar.core.domain.repository.ThemePreset
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepositoryImpl @Inject constructor(
    private val ds: SettingsDataStore,
) : SettingsRepository, PremiumRepository {

    override val settings: Flow<AppSettings> = ds.raw.map { p ->
        AppSettings(
            themeMode = p[SettingsDataStore.Keys.THEME_MODE]
                ?.let { runCatching { ThemeMode.valueOf(it) }.getOrDefault(ThemeMode.SYSTEM) }
                ?: ThemeMode.SYSTEM,
            themePreset = ThemePreset.fromName(p[SettingsDataStore.Keys.THEME_PRESET]),
            customPrimaryColor = p[SettingsDataStore.Keys.CUSTOM_PRIMARY] ?: 0xFF1E5AA8,
            currencyUnit = p[SettingsDataStore.Keys.CURRENCY_UNIT] ?: "TOMAN",
            defaultTaxPercent = p[SettingsDataStore.Keys.DEFAULT_TAX] ?: 10.0,
            defaultTerms = p[SettingsDataStore.Keys.DEFAULT_TERMS] ?: "",
            invoicePrefixes = InvoiceType.entries.associateWith { type ->
                p[SettingsDataStore.Keys.prefixKey(type.name)] ?: type.defaultPrefix
            },
            paperSizeMm = p[SettingsDataStore.Keys.PAPER_SIZE] ?: 80,
            lastPrinterMac = p[SettingsDataStore.Keys.LAST_PRINTER_MAC],
            printShowLogo = p[SettingsDataStore.Keys.PRINT_SHOW_LOGO] ?: true,
            printShowSignature = p[SettingsDataStore.Keys.PRINT_SHOW_SIGNATURE] ?: true,
            printShowTerms = p[SettingsDataStore.Keys.PRINT_SHOW_TERMS] ?: true,
            weeklyBackupEnabled = p[SettingsDataStore.Keys.WEEKLY_BACKUP] ?: false,
            isPremium = p[SettingsDataStore.Keys.IS_PREMIUM] ?: false,
        )
    }

    override val isPremium: Flow<Boolean> = settings.map { it.isPremium }

    override suspend fun setPremium(value: Boolean) = ds.set(SettingsDataStore.Keys.IS_PREMIUM, value)

    override suspend fun setThemeMode(mode: ThemeMode) = ds.set(SettingsDataStore.Keys.THEME_MODE, mode.name)

    override suspend fun setThemePreset(preset: ThemePreset) = ds.set(SettingsDataStore.Keys.THEME_PRESET, preset.name)

    override suspend fun setCustomPrimaryColor(argb: Long) {
        ds.set(SettingsDataStore.Keys.CUSTOM_PRIMARY, argb)
        ds.set(SettingsDataStore.Keys.THEME_PRESET, ThemePreset.CUSTOM.name)
    }

    override suspend fun setCurrencyUnit(unit: String) = ds.set(SettingsDataStore.Keys.CURRENCY_UNIT, unit)

    override suspend fun setDefaultTaxPercent(percent: Double) =
        ds.set(SettingsDataStore.Keys.DEFAULT_TAX, percent)

    override suspend fun setDefaultTerms(terms: String) = ds.set(SettingsDataStore.Keys.DEFAULT_TERMS, terms)

    override suspend fun setInvoicePrefix(type: InvoiceType, prefix: String) =
        ds.set(SettingsDataStore.Keys.prefixKey(type.name), prefix.ifBlank { type.defaultPrefix })

    override suspend fun consumeNextNumber(type: InvoiceType): String {
        val p = ds.snapshot()
        val prefix = p[SettingsDataStore.Keys.prefixKey(type.name)] ?: type.defaultPrefix
        val next = p[SettingsDataStore.Keys.nextNumberKey(type.name)] ?: 1L
        ds.set(SettingsDataStore.Keys.nextNumberKey(type.name), next + 1)
        return formatNumber(prefix, next)
    }

    override suspend fun previewNextNumber(type: InvoiceType): String {
        val p = ds.snapshot()
        val prefix = p[SettingsDataStore.Keys.prefixKey(type.name)] ?: type.defaultPrefix
        val next = p[SettingsDataStore.Keys.nextNumberKey(type.name)] ?: 1L
        return formatNumber(prefix, next)
    }

    override suspend fun setNextNumber(type: InvoiceType, next: Long) =
        ds.set(SettingsDataStore.Keys.nextNumberKey(type.name), next.coerceAtLeast(1))

    private fun formatNumber(prefix: String, number: Long): String {
        val year = ir.factoryar.core.common.jalali.JalaliConverter.today().year
        return "$prefix-$year-${number.toString().padStart(5, '0')}"
    }

    override suspend fun setPaperSize(mm: Int) = ds.set(SettingsDataStore.Keys.PAPER_SIZE, if (mm == 58) 58 else 80)

    override suspend fun setLastPrinterMac(mac: String?) {
        if (mac == null) ds.remove(SettingsDataStore.Keys.LAST_PRINTER_MAC)
        else ds.set(SettingsDataStore.Keys.LAST_PRINTER_MAC, mac)
    }

    override suspend fun setPrintFlags(showLogo: Boolean, showSignature: Boolean, showTerms: Boolean) {
        ds.edit {
            it[SettingsDataStore.Keys.PRINT_SHOW_LOGO] = showLogo
            it[SettingsDataStore.Keys.PRINT_SHOW_SIGNATURE] = showSignature
            it[SettingsDataStore.Keys.PRINT_SHOW_TERMS] = showTerms
        }
    }

    override suspend fun setWeeklyBackupEnabled(enabled: Boolean) =
        ds.set(SettingsDataStore.Keys.WEEKLY_BACKUP, enabled)
}
