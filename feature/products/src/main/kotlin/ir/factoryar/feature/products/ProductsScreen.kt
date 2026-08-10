package ir.factoryar.feature.products

import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.barcode.BarcodeScannerDialog
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.repository.ProductFilter
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.SearchField
import ir.factoryar.core.ui.components.StatCard

@Composable
fun ProductsScreen(
    onBack: () -> Unit,
    onProductClick: (Long) -> Unit,
    onNewProduct: (barcode: String) -> Unit,
    viewModel: ProductsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showScanner by remember { mutableStateOf(false) }

    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.consumeMessage()
        }
    }

    Scaffold(
        topBar = {
            FyTopBar(
                title = "انبار کالا",
                onBack = onBack,
                actions = {
                    IconButton(onClick = { showScanner = true }) {
                        Icon(Icons.Filled.QrCodeScanner, contentDescription = "اسکن بارکد")
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { onNewProduct("") },
                icon = { Icon(Icons.Filled.Add, null) },
                text = { Text("کالای جدید") },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 90.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Row(
                    Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    StatCard(
                        title = "تعداد کالا",
                        value = state.summary.productCount.toString().toPersianDigits(),
                        modifier = Modifier.weight(1f),
                        icon = Icons.Filled.Inventory2,
                    )
                    StatCard(
                        title = "رو به اتمام",
                        value = state.summary.lowStockCount.toString().toPersianDigits(),
                        modifier = Modifier.weight(1f),
                        icon = Icons.Filled.Warning,
                        containerColor = if (state.summary.lowStockCount > 0) {
                            MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f)
                        } else {
                            MaterialTheme.colorScheme.surfaceVariant
                        },
                        onClick = { viewModel.setFilter(ProductFilter.LOW_STOCK) },
                    )
                }
            }

            item {
                Column(Modifier.padding(horizontal = 16.dp)) {
                    Text(
                        "ارزش کل انبار (بر مبنای بهای تمام‌شده)",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    MoneyText(state.summary.totalStockValue, style = MaterialTheme.typography.titleMedium)
                }
            }

            item {
                SearchField(
                    value = state.query,
                    onValueChange = viewModel::setQuery,
                    modifier = Modifier.padding(horizontal = 16.dp),
                    placeholder = "جستجوی نام، بارکد یا کد کالا…",
                )
            }

            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(ProductFilter.entries.toList()) { f ->
                        FilterChip(
                            selected = state.filter == f,
                            onClick = { viewModel.setFilter(f) },
                            label = { Text(f.faName, style = MaterialTheme.typography.labelMedium) },
                        )
                    }
                }
            }

            if (state.categories.isNotEmpty()) {
                item {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        item {
                            FilterChip(
                                selected = state.categoryId == null,
                                onClick = { viewModel.setCategory(null) },
                                label = { Text("همه دسته‌ها", style = MaterialTheme.typography.labelSmall) },
                            )
                        }
                        items(state.categories) { c ->
                            FilterChip(
                                selected = state.categoryId == c.id,
                                onClick = { viewModel.setCategory(if (state.categoryId == c.id) null else c.id) },
                                label = { Text(c.name, style = MaterialTheme.typography.labelSmall) },
                            )
                        }
                    }
                }
            }

            if (state.products.isEmpty() && !state.isLoading) {
                item {
                    EmptyState(
                        icon = Icons.Filled.Inventory2,
                        title = "هنوز کالایی ثبت نشده",
                        description = "کالاهای خود را با موجودی و بهای تمام‌شده تعریف کنید تا موجودی هنگام صدور فاکتور خودکار کم شود.",
                        actionLabel = "افزودن اولین کالا",
                        onAction = { onNewProduct("") },
                        modifier = Modifier.height(320.dp),
                    )
                }
            }

            items(state.products, key = { it.product.id }) { row ->
                ProductRow(
                    row = row,
                    onClick = { onProductClick(row.product.id) },
                )
            }
        }
    }

    if (showScanner) {
        BarcodeScannerDialog(
            onDismiss = { showScanner = false },
            onBarcode = { code ->
                showScanner = false
                viewModel.onBarcodeScanned(
                    barcode = code,
                    onFound = { onProductClick(it.id) },
                    onNotFound = { onNewProduct(it) },
                )
            },
        )
    }
}

@Composable
private fun ProductRow(
    row: ir.factoryar.core.domain.model.ProductWithCategory,
    onClick: () -> Unit,
) {
    val p = row.product
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = if (p.isLowStock) {
                MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.35f)
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
            },
        ),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        p.name,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (p.isLowStock) {
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            Icons.Filled.Warning,
                            null,
                            Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // categoryName در ماژول دیگری تعریف شده، پس smart cast ممکن نیست
                    val categoryName = row.categoryName
                    if (categoryName != null) {
                        Text(
                            categoryName,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Text(" • ", style = MaterialTheme.typography.labelSmall)
                    }
                    Text(
                        if (p.isService) {
                            "خدمات"
                        } else {
                            "موجودی: ${PersianFormatter.formatQuantity(p.stockQuantity)} ${p.unit}"
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = if (p.isOutOfStock) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                    if (p.barcode.isNotBlank()) {
                        Text(
                            " • ${p.barcode.toPersianDigits()}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                MoneyText(p.retailPrice, style = MaterialTheme.typography.bodyMedium)
                if (p.costPrice > 0) {
                    Text(
                        "سود: ${PersianFormatter.formatMoney(p.retailPrice - p.costPrice)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
