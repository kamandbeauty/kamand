@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.data.local.entity.AppSettingsEntity
import ir.javid.hesabyar.domain.repository.BackupRepository
import ir.javid.hesabyar.domain.repository.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.InputStream
import java.io.OutputStream
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(private val settingsRepository: SettingsRepository, private val backupRepository: BackupRepository) : ViewModel() {
    val settings = settingsRepository.settings
    val license = settingsRepository.license
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    fun save(settings: AppSettingsEntity, done: () -> Unit) = viewModelScope.launch { runCatching { settingsRepository.save(settings) }.fold({ done() }, { _message.value = it.message ?: "ذخیره تنظیمات ناموفق بود" }) }
    fun activate(token: String, done: () -> Unit) = viewModelScope.launch { settingsRepository.activateProfessional(token).fold({ done() }, { _message.value = it.message ?: "فعال‌سازی ناموفق بود" }) }
    fun export(output: OutputStream?, done: () -> Unit) = viewModelScope.launch { if (output == null) { _message.value = "امکان ایجاد فایل پشتیبان وجود ندارد"; return@launch }; output.use { backupRepository.exportTo(it).fold({ done() }, { _message.value = it.message ?: "تهیه نسخه پشتیبان ناموفق بود" }) } }
    fun restore(input: InputStream?, done: () -> Unit) = viewModelScope.launch { if (input == null) { _message.value = "امکان خواندن فایل وجود ندارد"; return@launch }; input.use { backupRepository.restoreFrom(it).fold({ done() }, { _message.value = it.message ?: "بازیابی ناموفق بود" }) } }
    fun dismissMessage() { _message.value = null }
}

@Composable
fun SettingsScreen(onRestoreCompleted: () -> Unit, viewModel: SettingsViewModel = hiltViewModel()) {
    val settings by viewModel.settings.collectAsStateWithLifecycle(initialValue = AppSettingsEntity())
    val license by viewModel.license.collectAsStateWithLifecycle(initialValue = ir.javid.hesabyar.core.model.LicenseStatus())
    val message by viewModel.message.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var showBusiness by remember { mutableStateOf(false) }
    var showLicense by remember { mutableStateOf(false) }
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri -> if (uri != null) viewModel.export(context.contentResolver.openOutputStream(uri)) {} }
    val restoreLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if (uri != null) viewModel.restore(context.contentResolver.openInputStream(uri)) { onRestoreCompleted() } }
    AppScreen("تنظیمات") {
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
            item { SectionCard(onClick = { showBusiness = true }) { Text("اطلاعات کسب‌وکار", fontWeight = FontWeight.Bold); Text(settings.businessName.ifBlank { "نام کسب‌وکار را ثبت کنید" }, color = MaterialTheme.colorScheme.onSurfaceVariant); Text("واحد پول: ${if (settings.currency == "TOMAN") "تومان" else "ریال"} • مالیات: ${if (settings.taxEnabled) "فعال (${settings.taxRate}٪)" else "غیرفعال"}", style = MaterialTheme.typography.labelMedium) } }
            item { SectionCard { Text("نسخه برنامه", fontWeight = FontWeight.Bold); Text(license.reason, color = if (license.isProfessional) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant); OutlinedButton(onClick = { showLicense = true }) { Text(if (license.isProfessional) "مشاهده مجوز" else "فعال‌سازی نسخه حرفه‌ای") } } }
            item { SectionCard { Text("پشتیبان‌گیری و بازیابی", fontWeight = FontWeight.Bold); Text("فایل پشتیبان فقط شامل اطلاعات حسابداری شماست و روی حافظه انتخابی خودتان ذخیره می‌شود.", color = MaterialTheme.colorScheme.onSurfaceVariant); Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Button(onClick = { exportLauncher.launch("hesabyar_backup_${PersianDate.format(PersianDate.today()).replace("/", "")}.db") }, Modifier.weight(1f)) { Text("ایجاد Backup") }; OutlinedButton(onClick = { restoreLauncher.launch(arrayOf("application/octet-stream", "application/x-sqlite3")) }, Modifier.weight(1f)) { Text("بازیابی") } } } }
            item { SectionCard { Text("حریم خصوصی", fontWeight = FontWeight.Bold); Text("حسابیار جاوید در نسخه اول بدون اینترنت کار می‌کند و داده‌ها فقط روی همین دستگاه نگهداری می‌شوند.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
        }
    }
    if (showBusiness) BusinessEditor(settings, { showBusiness = false }, { viewModel.save(it) { showBusiness = false } })
    if (showLicense) LicenseEditor(license.isProfessional, { showLicense = false }, { viewModel.activate(it) { showLicense = false } })
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun BusinessEditor(settings: AppSettingsEntity, onDismiss: () -> Unit, onSave: (AppSettingsEntity) -> Unit) {
    var business by remember(settings) { mutableStateOf(settings.businessName) }; var owner by remember(settings) { mutableStateOf(settings.ownerName) }; var phone by remember(settings) { mutableStateOf(settings.phone) }; var address by remember(settings) { mutableStateOf(settings.address) }; var prefix by remember(settings) { mutableStateOf(settings.invoicePrefix) }; var taxEnabled by remember(settings) { mutableStateOf(settings.taxEnabled) }; var taxRate by remember(settings) { mutableStateOf(settings.taxRate.toString()) }; var currency by remember(settings) { mutableStateOf(settings.currency) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("تنظیمات کسب‌وکار") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(business, { business = it }, "نام کسب‌وکار"); FormTextField(owner, { owner = it }, "نام مالک"); FormTextField(phone, { phone = it }, "شماره تماس"); FormTextField(address, { address = it }, "آدرس", singleLine = false); FormTextField(prefix, { prefix = it }, "پیش‌شماره فاکتور"); Row { Switch(taxEnabled, { taxEnabled = it }); Spacer(Modifier.width(8.dp)); Text("فعال‌سازی مالیات ارزش افزوده") }; if (taxEnabled) FormTextField(taxRate, { taxRate = it }, "نرخ مالیات (درصد)"); SingleChoiceSegmentedButtonRow { listOf("TOMAN" to "تومان", "RIAL" to "ریال").forEachIndexed { i, option -> SegmentedButton(currency == option.first, { currency = option.first }, SegmentedButtonDefaults.itemShape(i, 2)) { Text(option.second) } } } } }, confirmButton = { TextButton(onClick = { onSave(settings.copy(businessName = business, ownerName = owner, phone = phone, address = address, invoicePrefix = prefix, taxEnabled = taxEnabled, taxRate = taxRate.toDoubleOrNull() ?: 0.0, currency = currency)) }) { Text("ذخیره") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun LicenseEditor(active: Boolean, onDismiss: () -> Unit, onActivate: (String) -> Unit) { var token by remember { mutableStateOf("") }; AlertDialog(onDismissRequest = onDismiss, title = { Text(if (active) "نسخه حرفه‌ای فعال است" else "فعال‌سازی نسخه حرفه‌ای") }, text = { if (active) Text("محدودیت‌های نسخه حرفه‌ای برای این دستگاه برداشته شده است.") else Column { Text("کد فعال‌سازی را وارد کنید."); FormTextField(token, { token = it }, "کد فعال‌سازی") } }, confirmButton = { if (!active) TextButton(onClick = { onActivate(token) }) { Text("فعال‌سازی") } else TextButton(onClick = onDismiss) { Text("باشه") } }, dismissButton = { if (!active) TextButton(onClick = onDismiss) { Text("انصراف") } }) }
