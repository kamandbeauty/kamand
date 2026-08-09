package ir.factoryar.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.billing.BillingManager
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.repository.AppSettings
import ir.factoryar.core.domain.repository.BackupRepository
import ir.factoryar.core.domain.repository.BusinessRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.repository.ThemeMode
import ir.factoryar.core.domain.repository.ThemePreset
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val profile: BusinessProfile = BusinessProfile(),
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val businessRepository: BusinessRepository,
    private val backupRepository: BackupRepository,
    val billingManager: BillingManager,
) : ViewModel() {

    val uiState: StateFlow<SettingsUiState> = combine(
        settingsRepository.settings,
        businessRepository.observeActiveProfile(),
    ) { settings, profile ->
        SettingsUiState(settings = settings, profile = profile ?: BusinessProfile())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SettingsUiState())

    private val _messages = MutableSharedFlow<String>()
    val messages: SharedFlow<String> = _messages

    // تم
    fun setThemeMode(mode: ThemeMode) = viewModelScope.launch { settingsRepository.setThemeMode(mode) }
    fun setThemePreset(preset: ThemePreset) = viewModelScope.launch { settingsRepository.setThemePreset(preset) }
    fun setCustomColor(argb: Long) = viewModelScope.launch { settingsRepository.setCustomPrimaryColor(argb) }
    fun setCurrencyUnit(unit: String) = viewModelScope.launch { settingsRepository.setCurrencyUnit(unit) }

    // فاکتور
    fun setDefaultTax(value: Double) = viewModelScope.launch { settingsRepository.setDefaultTaxPercent(value) }
    fun setDefaultTerms(value: String) = viewModelScope.launch { settingsRepository.setDefaultTerms(value) }
    fun setInvoicePrefix(type: InvoiceType, prefix: String) = viewModelScope.launch { settingsRepository.setInvoicePrefix(type, prefix) }
    fun setNextNumber(type: InvoiceType, next: Long) = viewModelScope.launch { settingsRepository.setNextNumber(type, next) }

    // چاپ
    fun setPaperSize(mm: Int) = viewModelScope.launch { settingsRepository.setPaperSize(mm) }
    fun setPrintFlags(logo: Boolean, signature: Boolean, terms: Boolean) =
        viewModelScope.launch { settingsRepository.setPrintFlags(logo, signature, terms) }

    // کسب‌وکار
    fun saveProfile(profile: BusinessProfile) = viewModelScope.launch {
        businessRepository.save(profile.copy(isActive = true))
        _messages.emit("اطلاعات کسب‌وکار ذخیره شد")
    }

    // پشتیبان‌گیری
    fun setWeeklyBackup(enabled: Boolean) = viewModelScope.launch { settingsRepository.setWeeklyBackupEnabled(enabled) }

    fun exportBackup(uri: String) = viewModelScope.launch {
        backupRepository.exportLocalBackup(uri)
            .onSuccess { _messages.emit("پشتیبان‌گیری انجام شد") }
            .onFailure { _messages.emit("خطا: ${it.message}") }
    }

    fun importBackup(uri: String) = viewModelScope.launch {
        backupRepository.importLocalBackup(uri)
            .onSuccess { _messages.emit("بازیابی انجام شد؛ اپ را ببندید و دوباره باز کنید") }
            .onFailure { _messages.emit("خطا: ${it.message}") }
    }
}
