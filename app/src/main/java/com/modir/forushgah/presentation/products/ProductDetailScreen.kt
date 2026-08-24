package com.modir.forushgah.presentation.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.DateTimeFormatter
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.core.designsystem.component.StockBadge
import com.modir.forushgah.core.designsystem.component.stockLevelOf
import com.modir.forushgah.domain.model.InventoryMovement
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.model.Product
import kotlin.math.abs

@Composable
fun ProductDetailRoute(
    onBack: () -> Unit,
    onEdit: () -> Unit,
    viewModel: ProductDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var showAdjustment by remember { mutableStateOf(false) }
    var showArchiveConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(event) {
        when (val e = event) {
            ProductDetailEvent.StockAdjusted -> showAdjustment = false
            ProductDetailEvent.ProductArchived -> onBack()
            is ProductDetailEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    ProductDetailScreen(
        state = state,
        showAdjustment = showAdjustment,
        showArchiveConfirm = showArchiveConfirm,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onEdit = onEdit,
        onAdjustStockClick = { showAdjustment = true },
        onArchiveClick = { showArchiveConfirm = true },
        onAdjustmentConfirm = viewModel::adjustStock,
        onAdjustmentDismiss = { showAdjustment = false },
        onArchiveConfirmed = viewModel::archiveProduct,
        onArchiveDismiss = { showArchiveConfirm = false },
    )
}

@Composable
fun ProductDetailScreen(
    state: ProductDetailUiState,
    showAdjustment: Boolean,
    showArchiveConfirm: Boolean,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onAdjustStockClick: () -> Unit,
    onArchiveClick: () -> Unit,
    onAdjustmentConfirm: (newStock: Int, reason: String?) -> Unit,
    onAdjustmentDismiss: () -> Unit,
    onArchiveConfirmed: () -> Unit,
    onArchiveDismiss: () -> Unit,
) {
    val product = state.product

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("جزئیات محصول") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
                actions = {
                    if (product != null) {
                        IconButton(onClick = onEdit) {
                            Icon(Icons.Filled.Edit, contentDescription = "ویرایش")
                        }
                        IconButton(onClick = onArchiveClick) {
                            Icon(Icons.Filled.Archive, contentDescription = "بایگانی")
                        }
                    }
                },
            )
        },
    ) { padding ->
        when {
            state.isLoading -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
            product == null -> Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                EmptyState(
                    title = "محصول یافت نشد",
                    subtitle = "این محصول دیگر در دسترس نیست",
                    ctaLabel = "بازگشت",
                    onCtaClick = onBack,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
            else -> ProductDetailContent(
                state = state,
                onAdjustStockClick = onAdjustStockClick,
                modifier = Modifier.padding(padding),
            )
        }
    }

    if (showAdjustment && product != null) {
        StockAdjustmentSheet(
            currentStock = product.stockQuantity,
            onConfirm = onAdjustmentConfirm,
            onDismiss = onAdjustmentDismiss,
        )
    }

    if (showArchiveConfirm && product != null) {
        AlertDialog(
            onDismissRequest = onArchiveDismiss,
            title = { Text("بایگانی محصول") },
            text = {
                Text("«${product.name}» بایگانی می‌شود و دیگر در لیست محصولات نمایش داده نمی‌شود.")
            },
            confirmButton = { TextButton(onClick = onArchiveConfirmed) { Text("بایگانی") } },
            dismissButton = { TextButton(onClick = onArchiveDismiss) { Text("انصراف") } },
        )
    }
}

@Composable
private fun ProductDetailContent(
    state: ProductDetailUiState,
    onAdjustStockClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val product = state.product!!
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { StockCard(product = product, onAdjustStockClick = onAdjustStockClick) }
        item { PricesCard(product = product) }
        item { InfoCard(state = state) }
        if (product.notes != null) {
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("یادداشت", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(product.notes, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
        item {
            Column(modifier = Modifier.padding(top = 4.dp)) {
                Text("تاریخچه موجودی", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                if (state.movements.isEmpty()) {
                    Text(
                        "گردش کالایی ثبت نشده",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        items(state.movements, key = { it.id }) { movement ->
            MovementCard(movement = movement)
        }
    }
}

@Composable
private fun StockCard(product: Product, onAdjustStockClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("موجودی فعلی", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        PersianNumberFormatter.toPersianDigits(product.stockQuantity.toString()),
                        style = MaterialTheme.typography.headlineLarge,
                    )
                    Text(
                        "حداقل موجودی هشدار: ${PersianNumberFormatter.toPersianDigits(product.minimumStock.toString())}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                StockBadge(level = stockLevelOf(product.stockQuantity, product.minimumStock), alwaysShow = true)
            }
            TextButton(onClick = onAdjustStockClick) {
                Icon(Icons.Filled.SwapVert, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text("تنظیم موجودی")
            }
        }
    }
}

@Composable
private fun PricesCard(product: Product) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("قیمت‌ها", style = MaterialTheme.typography.titleMedium)
            MoneyRow("قیمت خرید", product.purchasePrice)
            MoneyRow("قیمت فروش", product.sellingPrice)
            MoneyRow("هزینه بسته‌بندی", product.packagingCost)
            Divider()
            MoneyRow("سود تخمینی هر واحد", product.estimatedProfitPerUnit, emphasized = true)
        }
    }
}

@Composable
private fun MoneyRow(label: String, value: Money, emphasized: Boolean = false) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            value.toPersianDisplayString(),
            style = if (emphasized) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyLarge,
            color = if (emphasized && value.isNegative) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun InfoCard(state: ProductDetailUiState) {
    val product = state.product!!
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("مشخصات", style = MaterialTheme.typography.titleMedium)
            InfoRow("کد محصول (SKU)", product.sku.ifBlank { "—" })
            if (product.barcode != null) InfoRow("بارکد", product.barcode)
            InfoRow("دسته‌بندی", state.categoryName ?: "—")
            InfoRow("وضعیت", if (product.isActive) "فعال" else "بایگانی‌شده")
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun MovementCard(movement: InventoryMovement) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    movement.movementType.persianLabel(),
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    formatDelta(movement.quantityDelta),
                    style = MaterialTheme.typography.titleMedium,
                    color = when {
                        movement.quantityDelta > 0 -> MaterialTheme.colorScheme.primary
                        movement.quantityDelta < 0 -> MaterialTheme.colorScheme.error
                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
            Text(
                "از ${PersianNumberFormatter.toPersianDigits(movement.stockBefore.toString())} به " +
                    "${PersianNumberFormatter.toPersianDigits(movement.stockAfter.toString())} — " +
                    "${DateTimeFormatter.dateTime(movement.createdAt)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            referenceLabelOf(movement)?.let { refLabel ->
                Text(
                    "مرجع: $refLabel",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            movement.note?.let {
                Text(it, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

/** Spec §6: movements show their reference (order, stock adjustment, manual). */
private fun referenceLabelOf(movement: InventoryMovement): String? = when (movement.referenceType) {
    InventoryReferenceType.ORDER -> "سفارش #${PersianNumberFormatter.toPersianDigits((movement.referenceId ?: 0L).toString())}"
    InventoryReferenceType.STOCK_ADJUSTMENT -> "تنظیم موجودی"
    InventoryReferenceType.MANUAL -> "ثبت دستی"
    InventoryReferenceType.NONE -> null
}

private fun formatDelta(delta: Int): String {
    val sign = when {
        delta > 0 -> "+"
        delta < 0 -> "−"
        else -> ""
    }
    return sign + PersianNumberFormatter.toPersianDigits(abs(delta).toString())
}

private fun InventoryMovementType.persianLabel(): String = when (this) {
    InventoryMovementType.PURCHASE -> "خرید"
    InventoryMovementType.SALE -> "فروش"
    InventoryMovementType.RETURN -> "مرجوعی"
    InventoryMovementType.ADJUSTMENT_IN -> "تنظیم موجودی (افزایش)"
    InventoryMovementType.ADJUSTMENT_OUT -> "تنظیم موجودی (کاهش)"
    InventoryMovementType.DAMAGED -> "آسیب‌دیده"
    InventoryMovementType.OTHER -> "سایر"
}
