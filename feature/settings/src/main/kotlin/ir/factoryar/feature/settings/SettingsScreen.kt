package ir.factoryar.feature.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Backup
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.repository.ThemeMode
import ir.factoryar.core.domain.repository.ThemePreset
import ir.factoryar.core.ui.components.ColorPickerDialog
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.SectionHeader
import ir.factoryar.core.ui.theme.ThemeSeeds
import kotlinx.coroutines.flow.collectLatest

@Composable
fun SettingsScreen(
    onGoPremium: () -> Unit,
    onBack: (() -> Unit)? = null,
    onOpenProducts: () -> Unit = {},
    onOpenExpenses: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current
    var showColorPicker by remember { mutableStateOf(false) }
    var showBusinessEditor by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { viewModel.messages.collectLatest { snackbar.showSnackbar(it) } }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip"),
    ) { uri: Uri? -> uri?.let { viewModel.exportBackup(it.toString()) } }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        uri?.let { viewModel.importBackup(it.toString()) }
    }

    Scaffold(
        topBar = { FyTopBar(title = "تنظیمات", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 40.dp),
        ) {
            // اشتراک
            SettingsCard {
                ListItem(
                    headlineContent = { Text(if (state.settings.isPremium) "اشتراک طلایی فعال ✨" else "نسخه رایگان") },
                    supportingContent = { Text(if (state.settings.isPremium) "از حمایت شما سپاسگزاریم" else "پشتیبان‌گیری ابری، گزارش PDF، چند کسب‌وکار و…") },
                    leadingContent = { Icon(Icons.Filled.WorkspacePremium, null, tint = Color(0xFFFFB300)) },
                    trailingContent = {
                        if (!state.settings.isPremium) TextButton(onClick = onGoPremium) { Text("ارتقا") }
                    },
                )
            }

            // ظاهری و تم
            SectionHeader(title = "ظاهری و تم")
            SettingsCard {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("حالت نمایش", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ThemeMode.entries.forEach { mode ->
                            FilterChip(
                                selected = state.settings.themeMode == mode,
                                onClick = { viewModel.setThemeMode(mode) },
                                label = {
                                    Text(
                                        when (mode) {
                                            ThemeMode.SYSTEM -> "خودکار (سیستم)"
                                            ThemeMode.LIGHT -> "روشن"
                                            ThemeMode.DARK -> "تاریک"
                                        },
                                    )
                                },
                            )
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    Text("تم رنگی", style = MaterialTheme.typography.labelMedium)
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        ThemePreset.entries.filter { it != ThemePreset.CUSTOM }.forEach { preset ->
                            ThemeSwatch(
                                color = Color(ThemeSeeds.seedFor(preset)),
                                label = preset.faName,
                                selected = state.settings.themePreset == preset,
                                onClick = { viewModel.setThemePreset(preset) },
                            )
                        }
                        // رنگ دلخواه — طلایی
                        ThemeSwatch(
                            color = if (state.settings.themePreset == ThemePreset.CUSTOM) Color(state.settings.customPrimaryColor) else Color(0xFF9E9E9E),
                            label = "دلخواه ⭐",
                            selected = state.settings.themePreset == ThemePreset.CUSTOM,
                            locked = !state.settings.isPremium,
                            onClick = {
                                if (state.settings.isPremium) showColorPicker = true else onGoPremium()
                            },
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                    Text("واحد پول", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = state.settings.currencyUnit == "TOMAN", onClick = { viewModel.setCurrencyUnit("TOMAN") }, label = { Text("تومان") })
                        FilterChip(selected = state.settings.currencyUnit == "RIAL", onClick = { viewModel.setCurrencyUnit("RIAL") }, label = { Text("ریال") })
                    }
                }
            }

            // مدیریت (رایگان)
            SectionHeader(title = "مدیریت کسب‌وکار")
            SettingsCard {
                Column {
                    ListItem(
                        headlineContent = { Text("انبار و کالاها") },
                        supportingContent = { Text("تعریف کالا، بارکد، موجودی و بهای تمام‌شده") },
                        leadingContent = { Icon(Icons.Filled.Inventory2, null) },
                        modifier = Modifier.clickable(onClick = onOpenProducts),
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = { Text("هزینه‌های کسب‌وکار") },
                        supportingContent = { Text("ثبت اجاره، حقوق، قبوض و محاسبه سود خالص") },
                        leadingContent = { Icon(Icons.Filled.ReceiptLong, null) },
                        modifier = Modifier.clickable(onClick = onOpenExpenses),
                    )
                }
            }

            // کسب‌وکار
            SectionHeader(title = "اطلاعات کسب‌وکار")
            SettingsCard {
                ListItem(
                    headlineContent = { Text(state.profile.name.ifBlank { "تنظیم نشده" }) },
                    supportingContent = { Text(state.profile.phone.ifBlank { "نام، لوگو، تلفن و آدرس روی فاکتور نمایش داده می‌شود".toPersianDigits() }) },
                    trailingContent = { TextButton(onClick = { showBusinessEditor = true }) { Text("ویرایش") } },
                )
            }

            // پیش‌فرض‌های فاکتور
            SectionHeader(title = "پیش‌فرض‌های فاکتور")
            SettingsCard {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    var taxText by remember(state.settings.defaultTaxPercent) {
                        mutableStateOf(PersianFormatter.formatQuantity(state.settings.defaultTaxPercent))
                    }
                    OutlinedTextField(
                        value = taxText,
                        onValueChange = {
                            taxText = it
                            PersianFormatter.parseDouble(it).let { v -> viewModel.setDefaultTax(v) }
                        },
                        label = { Text("مالیات پیش‌فرض (٪)") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    var termsText by remember(state.settings.defaultTerms) { mutableStateOf(state.settings.defaultTerms) }
                    OutlinedTextField(
                        value = termsText,
                        onValueChange = { termsText = it; viewModel.setDefaultTerms(it) },
                        label = { Text("شرایط پیش‌فرض فاکتور") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text("پیشوند و شماره‌گذاری", style = MaterialTheme.typography.labelMedium)
                    InvoiceType.entries.forEach { type ->
                        var prefix by remember(type, state.settings.invoicePrefixes) { mutableStateOf(state.settings.invoicePrefixes[type] ?: type.defaultPrefix) }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(type.faName, Modifier.width(80.dp), style = MaterialTheme.typography.bodySmall)
                            OutlinedTextField(
                                value = prefix,
                                onValueChange = { prefix = it; viewModel.setInvoicePrefix(type, it) },
                                singleLine = true,
                                modifier = Modifier.weight(1f),
                                textStyle = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }

            // چاپگر
            SectionHeader(title = "چاپگر پوز بلوتوثی")
            SettingsCard {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("اندازه کاغذ", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = state.settings.paperSizeMm == 58, onClick = { viewModel.setPaperSize(58) }, label = { Text("۵۸ میلی‌متر".toPersianDigits()) })
                        FilterChip(selected = state.settings.paperSizeMm == 80, onClick = { viewModel.setPaperSize(80) }, label = { Text("۸۰ میلی‌متر".toPersianDigits()) })
                    }
                    PrintFlagRow("نمایش لوگو روی رسید", state.settings.printShowLogo) { viewModel.setPrintFlags(it, state.settings.printShowSignature, state.settings.printShowTerms) }
                    PrintFlagRow("نمایش امضا روی رسید", state.settings.printShowSignature) { viewModel.setPrintFlags(state.settings.printShowLogo, it, state.settings.printShowTerms) }
                    PrintFlagRow("نمایش شرایط روی رسید", state.settings.printShowTerms) { viewModel.setPrintFlags(state.settings.printShowLogo, state.settings.printShowSignature, it) }
                }
            }

            // پشتیبان‌گیری
            SectionHeader(title = "پشتیبان‌گیری")
            SettingsCard {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Backup, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(8.dp))
                        Text("فایل ZIP محلی (بدون نیاز به اینترنت)", style = MaterialTheme.typography.titleSmall)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { exportLauncher.launch("factoryar_backup.zip") }, modifier = Modifier.weight(1f)) { Text("تهیه نسخه پشتیبان") }
                        OutlinedButton(onClick = { importLauncher.launch(arrayOf("application/zip", "application/octet-stream")) }, modifier = Modifier.weight(1f)) { Text("بازیابی") }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("پشتیبان‌گیری هفتگی خودکار", style = MaterialTheme.typography.bodyMedium)
                            Text("با WorkManager در پس‌زمینه", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(checked = state.settings.weeklyBackupEnabled, onCheckedChange = { viewModel.setWeeklyBackup(it) })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("همگام‌سازی ابری (Google Drive) ", style = MaterialTheme.typography.bodyMedium)
                                if (!state.settings.isPremium) Icon(Icons.Filled.Lock, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.outline)
                            }
                            Text("اشتراک طلایی", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(checked = false, enabled = state.settings.isPremium, onCheckedChange = { /* فاز ابری */ })
                    }
                }
            }

            // درباره
            SectionHeader(title = "درباره")
            SettingsCard {
                Column(Modifier.padding(12.dp)) {
                    Text("فاکتوریار — نسخه ۱٫۰", style = MaterialTheme.typography.titleSmall)
                    Text(
                        "صدور فاکتور، مدیریت مشتریان و چاپ بلوتوثی؛ کاملاً آفلاین. داده‌های شما رمزنگاری‌شده روی همین دستگاه ذخیره می‌شود.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    if (showColorPicker) {
        ColorPickerDialog(
            initialArgb = state.settings.customPrimaryColor,
            onDismiss = { showColorPicker = false },
            onConfirm = { viewModel.setCustomColor(it); showColorPicker = false },
        )
    }
    if (showBusinessEditor) {
        BusinessProfileDialog(
            initial = state.profile,
            onDismiss = { showBusinessEditor = false },
            onSave = { viewModel.saveProfile(it); showBusinessEditor = false },
        )
    }
}

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
    ) { content() }
}

@Composable
private fun ThemeSwatch(color: Color, label: String, selected: Boolean, onClick: () -> Unit, locked: Boolean = false) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(color)
                .border(
                    width = if (selected) 3.dp else 1.dp,
                    color = if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant,
                    shape = CircleShape,
                )
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            if (locked) Icon(Icons.Filled.Lock, null, Modifier.size(16.dp), tint = Color.White)
            else if (selected) Icon(Icons.Filled.Check, null, Modifier.size(18.dp), tint = Color.White)
        }
        Spacer(Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun PrintFlagRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
