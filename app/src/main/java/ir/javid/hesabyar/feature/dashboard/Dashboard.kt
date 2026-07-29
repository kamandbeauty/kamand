package ir.javid.hesabyar.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.core.model.DashboardSummary
import ir.javid.hesabyar.core.ui.AppScreen
import ir.javid.hesabyar.core.ui.LabeledValue
import ir.javid.hesabyar.core.ui.MoneyText
import ir.javid.hesabyar.core.ui.SectionCard
import ir.javid.hesabyar.domain.repository.DashboardRepository
import ir.javid.hesabyar.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

@HiltViewModel
class DashboardViewModel @Inject constructor(repository: DashboardRepository, productRepository: ProductRepository) : ViewModel() {
    val summary: Flow<DashboardSummary> = repository.summary
    val lowStock = productRepository.lowStock
}

@Composable
fun DashboardScreen(viewModel: DashboardViewModel = hiltViewModel(), onOpenProducts: () -> Unit) {
    val summary by viewModel.summary.collectAsStateWithLifecycle(initialValue = DashboardSummary())
    val lowStock by viewModel.lowStock.collectAsStateWithLifecycle(initialValue = emptyList())
    AppScreen("خانه") {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("سلام، خوش آمدید", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text("نمای کلی کسب‌وکار شما در امروز", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            SectionCard {
                Text("فروش امروز", color = MaterialTheme.colorScheme.onPrimaryContainer, style = MaterialTheme.typography.labelLarge)
                MoneyText(summary.salesToday, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.headlineMedium)
                Text("${PersianNumbers.toPersian(summary.invoicesToday.toString())} فاکتور ثبت شده", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MetricCard("خرید امروز", summary.purchasesToday, Modifier.weight(1f), MaterialTheme.colorScheme.tertiary)
                MetricCard("سود امروز", summary.profitToday, Modifier.weight(1f), MaterialTheme.colorScheme.primary)
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MetricCard("مانده صندوق", summary.cashBalance, Modifier.weight(1f), MaterialTheme.colorScheme.secondary)
                MetricCard("مانده بانک", summary.bankBalance, Modifier.weight(1f), MaterialTheme.colorScheme.secondary)
            }
        }
        item {
            SectionCard {
                Text("وضعیت مطالبات و بدهی‌ها", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    LabeledValue("بدهکاران", PersianNumbers.amount(summary.debtors), Modifier.weight(1f), MaterialTheme.colorScheme.error)
                    LabeledValue("بستانکاران", PersianNumbers.amount(summary.creditors), Modifier.weight(1f), MaterialTheme.colorScheme.tertiary)
                }
            }
        }
        item {
            SectionCard(onClick = onOpenProducts) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Icons.Outlined.Inventory2, null, tint = if (summary.lowStockCount > 0) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
                    Column(Modifier.weight(1f)) {
                        Text("هشدار موجودی کالا", fontWeight = FontWeight.Bold)
                        Text(if (summary.lowStockCount == 0) "همه کالاها موجودی مناسب دارند" else "${PersianNumbers.toPersian(summary.lowStockCount.toString())} کالا به حداقل موجودی رسیده‌اند", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        if (lowStock.isNotEmpty()) {
            items(lowStock.take(5), key = { it.id }) { product ->
                ListItem(headlineContent = { Text(product.name) }, supportingContent = { Text("موجودی: ${PersianNumbers.quantity(product.stock)} ${product.unit}") }, trailingContent = { Text("حداقل ${PersianNumbers.quantity(product.minimumStock)}") })
                HorizontalDivider()
            }
        }
    }
    }
}

@Composable
private fun MetricCard(title: String, amount: Long, modifier: Modifier, accent: Color) {
    ElevatedCard(modifier, colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            MoneyText(amount, color = accent, style = MaterialTheme.typography.titleMedium)
        }
    }
}
