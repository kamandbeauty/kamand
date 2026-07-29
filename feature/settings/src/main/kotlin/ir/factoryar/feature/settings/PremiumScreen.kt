package ir.factoryar.feature.settings

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
import androidx.compose.material.icons.filled.Backup
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.ColorLens
import androidx.compose.material.icons.filled.Domain
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.billing.BillingManager
import ir.factoryar.core.ui.components.FyTopBar
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private data class PremiumBenefit(val icon: ImageVector, val title: String, val desc: String)

private val benefits = listOf(
    PremiumBenefit(Icons.Filled.CloudDone, "پشتیبان‌گیری ابری", "بک‌آپ رمزنگاری‌شده روی Google Drive و بازگردانی روی گوشی جدید"),
    PremiumBenefit(Icons.Filled.PictureAsPdf, "گزارش PDF حرفه‌ای", "خروجی PDF گزارش‌های مالی برای ارائه و بایگانی"),
    PremiumBenefit(Icons.Filled.ColorLens, "رنگ دلخواه تم", "انتخاب آزاد رنگ اصلی اپ از میان میلیون‌ها رنگ"),
    PremiumBenefit(Icons.Filled.PictureAsPdf, "بدون واترمارک", "حذف برچسب «صادر شده با فاکتوریار» از PDF فاکتورها"),
    PremiumBenefit(Icons.Filled.Domain, "چند کسب‌وکار", "مدیریت چند فروشگاه/برند با پروفایل‌های جدا در یک اپ"),
)

@Composable
fun PremiumScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val activity = LocalContext.current as? androidx.activity.ComponentActivity
    var purchasing by remember { mutableStateOf(false) }
    var selectedSku by remember { mutableStateOf(BillingManager.Sku.YEARLY) }

    Scaffold(
        topBar = { FyTopBar(title = "اشتراک طلایی", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                    Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Surface(shape = CircleShape, color = MaterialTheme.colorScheme.primary, modifier = Modifier.size(64.dp)) {
                            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Filled.WorkspacePremium, null, Modifier.size(32.dp), tint = MaterialTheme.colorScheme.onPrimary)
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        Text("فاکتوریار طلایی", style = MaterialTheme.typography.titleLarge)
                        Text(
                            if (state.settings.isPremium) "اشتراک شما فعال است 🎉" else "همه قابلیت‌ها، یک‌بار فعال‌سازی",
                            style = MaterialTheme.typography.bodySmall,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }
            benefits.forEach { b ->
                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(b.icon, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(10.dp))
                        Column {
                            Text(b.title, style = MaterialTheme.typography.titleSmall)
                            Text(b.desc, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            if (!state.settings.isPremium) {
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        PlanCard(
                            title = "ماهانه",
                            price = "۵۹٬۰۰۰ تومان",
                            selected = selectedSku == BillingManager.Sku.MONTHLY,
                            onClick = { selectedSku = BillingManager.Sku.MONTHLY },
                            modifier = Modifier.weight(1f),
                        )
                        PlanCard(
                            title = "سالانه (پیشنهادی)",
                            price = "۵۹۰٬۰۰۰ تومان",
                            selected = selectedSku == BillingManager.Sku.YEARLY,
                            onClick = { selectedSku = BillingManager.Sku.YEARLY },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                item {
                    Button(
                        onClick = {
                            val registry = activity?.activityResultRegistry ?: return@Button
                            purchasing = true
                            viewModel.billingManager.connect()
                            viewModel.billingManager.purchasePremium(
                                registry = registry,
                                sku = selectedSku,
                                onSuccess = { purchasing = false; scope.launch { snackbar.showSnackbar("اشتراک طلایی فعال شد 🎉") } },
                                onCanceled = { purchasing = false },
                                onError = { msg -> purchasing = false; scope.launch { snackbar.showSnackbar(msg) } },
                            )
                        },
                        enabled = !purchasing,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                    ) {
                        if (purchasing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
                        else Text("فعال‌سازی با پرداخت بازار")
                    }
                    Text(
                        "پرداخت امن درون‌برنامه‌ای کافه‌بازار",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                    )
                }
                item {
                    OutlinedButton(
                        onClick = {
                            viewModel.billingManager.connect { active ->
                                scope.launch { snackbar.showSnackbar(if (active) "اشتراک بازیابی شد 🎉" else "خرید فعالی یافت نشد") }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("بازیابی خرید قبلی") }
                }
            }
            item { Spacer(Modifier.height(32.dp)) }
        }
    }
}

@Composable
private fun PlanCard(title: String, price: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Card(
        onClick = onClick,
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
        ),
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(6.dp))
            Text(price, style = MaterialTheme.typography.titleSmall)
        }
    }
}
