package ir.javid.hesabyar.feature.reports

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.core.model.ProfitLossSummary
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.domain.repository.ReportsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import javax.inject.Inject

@HiltViewModel
class ReportsViewModel @Inject constructor(repository: ReportsRepository) : ViewModel() {
    private val from = PersianDate.startOfMonth(PersianDate.today())
    private val to = PersianDate.today()
    val report: Flow<ReportState> = combine(repository.sales(from, to), repository.purchases(from, to), repository.expenses(from, to), repository.incomes(from, to), repository.profitLoss(from, to)) { sales, purchases, expenses, incomes, profit -> ReportState(sales, purchases, expenses, incomes, profit) }
}
data class ReportState(val sales: Long = 0, val purchases: Long = 0, val expenses: Long = 0, val incomes: Long = 0, val profitLoss: ProfitLossSummary = ProfitLossSummary(0, 0, 0, 0))

@Composable
fun ReportsScreen(viewModel: ReportsViewModel = hiltViewModel()) {
    val report by viewModel.report.collectAsStateWithLifecycle(initialValue = ReportState())
    AppScreen("گزارش‌ها") {
        Text("گزارش ماه جاری", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text("از ${PersianDate.format(PersianDate.startOfMonth(PersianDate.today()))} تا ${PersianDate.format(PersianDate.today())}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        SectionCard { Text("سود و زیان", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold); ReportRow("فروش کالا و خدمات", report.profitLoss.sales, true); ReportRow("بهای تمام‌شده", -report.profitLoss.costOfGoods); ReportRow("هزینه‌ها", -report.profitLoss.expenses); ReportRow("درآمدهای متفرقه", report.profitLoss.otherIncome, true); HorizontalDivider(); ReportRow("سود خالص", report.profitLoss.netProfit, report.profitLoss.netProfit >= 0, bold = true) }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) { SmallReportCard("فروش ماه", report.sales, Modifier.weight(1f)); SmallReportCard("خرید ماه", report.purchases, Modifier.weight(1f)) }
        SectionCard { Text("گزارش‌های تفصیلی", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold); Text("دفتر روزانه، دفتر کل و تراز آزمایشی در بخش «حسابداری» در دسترس هستند.", color = MaterialTheme.colorScheme.onSurfaceVariant); Text("گردش حساب اشخاص از بخش «اشخاص» و گردش کالا از بخش «کالاها» قابل مشاهده است.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
private fun ReportRow(label: String, amount: Long, positive: Boolean = amount >= 0, bold: Boolean = false) { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text(label, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal); Text(PersianNumbers.amount(kotlin.math.abs(amount)), color = if (positive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal) } }
@Composable
private fun SmallReportCard(label: String, amount: Long, modifier: Modifier) { ElevatedCard(modifier) { Column(Modifier.padding(12.dp)) { Text(label, style = MaterialTheme.typography.labelMedium); MoneyText(amount, style = MaterialTheme.typography.titleSmall) } } }
