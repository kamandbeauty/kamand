package com.modir.forushgah.presentation.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (snapshot.todayActions.isNotEmpty()) {
            item { Text("امروز چه کار کنم؟", style = MaterialTheme.typography.titleLarge) }
            items(snapshot.todayActions) { action -> TodayActionRow(action) }
            item { Spacer(modifier = Modifier.height(4.dp)) }
        }

        item {
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.height(360.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { StatCard("فروش امروز", snapshot.todaySales.toPersianDisplayString(), emphasis = true) }
                item { StatCard("فروش این ماه", snapshot.monthSales.toPersianDisplayString()) }
                item { StatCard("سود خالص", snapshot.netProfit.toPersianDisplayString()) }
                item { StatCard("سفارش‌های امروز", snapshot.todayOrderCount.toString()) }
                item { StatCard("سفارش‌های در انتظار", snapshot.pendingOrderCount.toString()) }
                item { StatCard("مطالبات", snapshot.totalReceivables.toPersianDisplayString()) }
                item { StatCard("بدهی‌ها", snapshot.totalPayables.toPersianDisplayString()) }
                item { StatCard("ارزش موجودی کالا", snapshot.inventoryValue.toPersianDisplayString()) }
            }
        }
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
