package com.modir.forushgah.presentation.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.core.designsystem.component.StatCard
import com.modir.forushgah.core.designsystem.theme.LocalSemanticColors
import com.modir.forushgah.domain.model.ActionSeverity
import com.modir.forushgah.domain.model.DashboardSnapshot
import com.modir.forushgah.domain.model.TodayActionItem

@Composable
fun DashboardRoute(
    onStartFirstOrder: () -> Unit,
    viewModel: DashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    DashboardScreen(state = state, onStartFirstOrder = onStartFirstOrder)
}

@Composable
fun DashboardScreen(
    state: DashboardUiState,
    onStartFirstOrder: () -> Unit,
) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("خانه") }) },
    ) { padding ->
        when (state) {
            is DashboardUiState.Loading -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator() }

            is DashboardUiState.Error -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) { Text(state.message, color = MaterialTheme.colorScheme.error) }

            is DashboardUiState.Content -> {
                if (!state.snapshot.hasAnyData) {
                    Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                        EmptyState(
                            title = "هنوز چیزی ثبت نشده",
                            subtitle = "با ثبت اولین سفارش، آمار فروشگاهت اینجا نمایش داده می‌شود",
                            ctaLabel = "ثبت اولین سفارش",
                            onCtaClick = onStartFirstOrder,
                        )
                    }
                } else {
                    DashboardContent(snapshot = state.snapshot, modifier = Modifier.padding(padding))
                }
            }
        }
    }
}

@Composable
private fun DashboardContent(snapshot: DashboardSnapshot, modifier: Modifier = Modifier) {
    // The stat grid is a plain scrollable Column of 2-up rows — NOT a lazy
    // layout. A lazy layout nested inside this screen's lazy list crashes on
    // real devices ("LazyLayout should be laid out with a size"): a parent
    // lazy item does not give its children the fixed-size constraints a
    // LazyLayout requires. The eight stats are static, so a plain layout is
    // correct and cheaper.
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (snapshot.todayActions.isNotEmpty()) {
            Text("امروز چه کار کنم؟", style = MaterialTheme.typography.titleLarge)
            snapshot.todayActions.forEach { action -> TodayActionRow(action) }
            Spacer(modifier = Modifier.height(4.dp))
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            StatGridRow(
                labelA = "فروش امروز", valueA = snapshot.todaySales.toPersianDisplayString(), emphasisA = true,
                labelB = "فروش این ماه", valueB = snapshot.monthSales.toPersianDisplayString(), emphasisB = false,
            )
            StatGridRow(
                labelA = "سود خالص", valueA = snapshot.netProfit.toPersianDisplayString(), emphasisA = false,
                labelB = "سفارش‌های امروز", valueB = snapshot.todayOrderCount.toString(), emphasisB = false,
            )
            StatGridRow(
                labelA = "سفارش‌های در انتظار", valueA = snapshot.pendingOrderCount.toString(), emphasisA = false,
                labelB = "مطالبات", valueB = snapshot.totalReceivables.toPersianDisplayString(), emphasisB = false,
            )
            StatGridRow(
                labelA = "بدهی‌ها", valueA = snapshot.totalPayables.toPersianDisplayString(), emphasisA = false,
                labelB = "ارزش موجودی کالا", valueB = snapshot.inventoryValue.toPersianDisplayString(), emphasisB = false,
            )
        }
    }
}

/** Two equal-width stat cards side by side (the dashboard's 2-up stat row). */
@Composable
private fun StatGridRow(
    labelA: String,
    valueA: String,
    emphasisA: Boolean,
    labelB: String,
    valueB: String,
    emphasisB: Boolean,
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        StatCard(label = labelA, value = valueA, modifier = Modifier.weight(1f), emphasis = emphasisA)
        StatCard(label = labelB, value = valueB, modifier = Modifier.weight(1f), emphasis = emphasisB)
    }
}

@Composable
private fun TodayActionRow(action: TodayActionItem) {
    val semantic = LocalSemanticColors.current
    val (dotColor, containerColor) = when (action.severity) {
        ActionSeverity.CRITICAL -> semantic.warning to semantic.warningContainer
        ActionSeverity.HIGH -> semantic.warning to semantic.warningContainer
        ActionSeverity.MEDIUM -> semantic.info to semantic.infoContainer
        ActionSeverity.INFO -> semantic.info to semantic.infoContainer
    }
    Surface(shape = RoundedCornerShape(14.dp), color = containerColor) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = Modifier.size(8.dp).background(color = dotColor, shape = CircleShape))
            Spacer(modifier = Modifier.width(10.dp))
            Text(text = action.label, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
