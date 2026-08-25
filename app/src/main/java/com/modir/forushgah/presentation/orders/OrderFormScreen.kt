package com.modir.forushgah.presentation.orders

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.AlertDialog
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isNegative
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.common.isZero
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.presentation.common.CustomerSelectorDialog
import com.modir.forushgah.presentation.common.ProductSelectorDialog

/** What the discount dialog edits: the whole order or one line (spec §7). */
sealed class DiscountTarget {
    data object Order : DiscountTarget()
    data class Item(val productId: Long) : DiscountTarget()
}

@Composable
fun OrderFormRoute(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: OrderFormViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    var showCustomerSelector by remember { mutableStateOf(false) }
    var showProductSelector by remember { mutableStateOf(false) }
    var discountTarget by remember { mutableStateOf<DiscountTarget?>(null) }

    LaunchedEffect(state.isSaved) {
        if (state.isSaved) onSaved()
    }

    OrderFormScreen(
        state = state,
        showCustomerSelector = showCustomerSelector,
        showProductSelector = showProductSelector,
        onCustomerSelectorDismiss = { showCustomerSelector = false },
        onProductSelectorDismiss = { showProductSelector = false },
        discountTarget = discountTarget,
        onBack = onBack,
        onCustomerSelectClick = { showCustomerSelector = true },
        onCustomerQueryChange = viewModel::onCustomerQueryChange,
        onCustomerSelected = { c ->
            viewModel.onCustomerSelected(c)
            showCustomerSelector = false
        },
        onQuickCreateCustomer = { n, m ->
            viewModel.onQuickCreateCustomer(n, m)
            showCustomerSelector = false
        },
        onProductSelectClick = { showProductSelector = true },
        onProductQueryChange = viewModel::onProductQueryChange,
        onProductSelected = { p ->
            viewModel.onProductAdded(p)
            showProductSelector = false
        },
        onQuantityChange = viewModel::onQuantityChange,
        onUnitPriceChange = viewModel::onUnitPriceChange,
        onItemDiscountClick = { pid -> discountTarget = DiscountTarget.Item(pid) },
        onItemDiscountSet = { pid, d ->
            viewModel.onItemDiscount(pid, d)
            discountTarget = null
        },
        onOrderDiscountClick = { discountTarget = DiscountTarget.Order },
        onOrderDiscountSet = { d ->
            viewModel.onOrderDiscountChange(d)
            discountTarget = null
        },
        onDiscountDismiss = { discountTarget = null },
        onRemoveLine = viewModel::onRemoveLine,
        onSalesChannelChange = viewModel::onSalesChannelChange,
        onPaymentMethodChange = viewModel::onPaymentMethodChange,
        onShippingProviderChange = viewModel::onShippingProviderChange,
        onShippingPaymentTypeChange = viewModel::onShippingPaymentTypeChange,
        onShippingChargedChange = viewModel::onShippingChargedChange,
        onActualShippingCostChange = viewModel::onActualShippingCostChange,
        onPackagingCostChange = viewModel::onPackagingCostChange,
        onNotesChange = viewModel::onNotesChange,
        onSave = viewModel::save,
    )
}

/** One-screen, fast-flow order creation (spec §3/§27). */
@Composable
fun OrderFormScreen(
    state: OrderFormUiState,
    showCustomerSelector: Boolean,
    showProductSelector: Boolean,
    onCustomerSelectorDismiss: () -> Unit,
    onProductSelectorDismiss: () -> Unit,
    discountTarget: DiscountTarget?,
    onBack: () -> Unit,
    onCustomerSelectClick: () -> Unit,
    onCustomerQueryChange: (String) -> Unit,
    onCustomerSelected: (com.modir.forushgah.domain.model.Customer) -> Unit,
    onQuickCreateCustomer: (name: String, mobile: String?) -> Unit,
    onProductSelectClick: () -> Unit,
    onProductQueryChange: (String) -> Unit,
    onProductSelected: (com.modir.forushgah.domain.model.Product) -> Unit,
    onQuantityChange: (Long, Int) -> Unit,
    onUnitPriceChange: (Long, String) -> Unit,
    onItemDiscountClick: (Long) -> Unit,
    onItemDiscountSet: (Long, Money) -> Unit,
    onOrderDiscountClick: () -> Unit,
    onOrderDiscountSet: (Money) -> Unit,
    onDiscountDismiss: () -> Unit,
    onRemoveLine: (Long) -> Unit,
    onSalesChannelChange: (Long?) -> Unit,
    onPaymentMethodChange: (Long?) -> Unit,
    onShippingProviderChange: (Long?) -> Unit,
    onShippingPaymentTypeChange: (ShippingPaymentType) -> Unit,
    onShippingChargedChange: (String) -> Unit,
    onActualShippingCostChange: (String) -> Unit,
    onPackagingCostChange: (String) -> Unit,
    onNotesChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("ثبت سفارش") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
            )
        },
        bottomBar = { OrderFormSummary(state = state, onSave = onSave) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                CustomerCard(
                    customerName = state.selectedCustomer?.name,
                    customerMobile = state.selectedCustomer?.mobile,
                    onPickClick = onCustomerSelectClick,
                )
            }
            item { Text("کالاهای سفارش", style = MaterialTheme.typography.titleMedium) }
            items(state.lines, key = { it.productId }) { line ->
                LineCard(
                    line = line,
                    onQuantityChange = onQuantityChange,
                    onUnitPriceChange = onUnitPriceChange,
                    onItemDiscountClick = onItemDiscountClick,
                    onRemove = onRemoveLine,
                )
            }
            item {
                OutlinedButton(onClick = onProductSelectClick, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Add, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("افزودن کالا به سفارش")
                }
            }
            item {
                CostsCard(
                    orderDiscount = state.orderDiscount,
                    shippingProviderId = state.shippingProviderId,
                    shippingProviders = state.shippingProviders.map { it.name to it.id },
                    shippingPaymentType = state.shippingPaymentType,
                    shippingCharged = state.shippingCharged,
                    actualShippingCost = state.actualShippingCost,
                    packagingCost = state.packagingCost,
                    onOrderDiscountClick = onOrderDiscountClick,
                    onShippingProviderChange = onShippingProviderChange,
                    onShippingPaymentTypeChange = onShippingPaymentTypeChange,
                    onShippingChargedChange = onShippingChargedChange,
                    onActualShippingCostChange = onActualShippingCostChange,
                    onPackagingCostChange = onPackagingCostChange,
                )
            }
            item {
                PaymentChannelCard(
                    paymentMethods = state.paymentMethods.map { it.name to it.id },
                    paymentMethodId = state.paymentMethodId,
                    salesChannels = state.salesChannels.map { it.name to it.id },
                    salesChannelId = state.salesChannelId,
                    onPaymentMethodChange = onPaymentMethodChange,
                    onSalesChannelChange = onSalesChannelChange,
                )
            }
            item {
                OutlinedTextField(
                    value = state.notes,
                    onValueChange = onNotesChange,
                    label = { Text("یادداشت (اختیاری)") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (state.errors.isNotEmpty()) {
                item {
                    Column {
                        state.errors.forEach { message ->
                            Text(
                                text = message,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
        }
    }

    if (showCustomerSelector) {
        CustomerSelectorDialog(
            customers = state.customers,
            query = state.customerQuery,
            onQueryChange = onCustomerQueryChange,
            onSelected = onCustomerSelected,
            onQuickCreate = onQuickCreateCustomer,
            onDismiss = onCustomerSelectorDismiss,
        )
    }
    if (showProductSelector) {
        ProductSelectorDialog(
            products = state.products,
            query = state.productQuery,
            onQueryChange = onProductQueryChange,
            onSelected = onProductSelected,
            onDismiss = onProductSelectorDismiss,
        )
    }
    when (val target = discountTarget) {
        is DiscountTarget.Order -> DiscountDialog(
            title = "تخفیف سفارش",
            base = state.productSubtotal,
            current = state.orderDiscount,
            onConfirm = onOrderDiscountSet,
            onDismiss = onDiscountDismiss,
        )
        is DiscountTarget.Item -> state.lines.firstOrNull { it.productId == target.productId }?.let { line ->
            DiscountDialog(
                title = "تخفیف «${line.name}»",
                base = line.unitPriceMoney * line.quantity,
                current = line.itemDiscount,
                onConfirm = { onItemDiscountSet(line.productId, it) },
                onDismiss = onDiscountDismiss,
            )
        }
        null -> Unit
    }
}

@Composable
private fun CustomerCard(customerName: String?, customerMobile: String?, onPickClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("مشتری", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(4.dp))
                if (customerName != null) {
                    Text(customerName, style = MaterialTheme.typography.titleMedium)
                    customerMobile?.let {
                        Text(
                            PersianNumberFormatter.toPersianDigits(it),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    Text("مشتری انتخاب نشده است", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
                }
            }
            TextButton(onClick = onPickClick) {
                Text(if (customerName != null) "تغییر مشتری" else "انتخاب مشتری")
            }
        }
    }
}

@Composable
private fun LineCard(
    line: OrderLineUi,
    onQuantityChange: (Long, Int) -> Unit,
    onUnitPriceChange: (Long, String) -> Unit,
    onItemDiscountClick: (Long) -> Unit,
    onRemove: (Long) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(line.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, modifier = Modifier.weight(1f))
                IconButton(onClick = { onRemove(line.productId) }) {
                    Icon(Icons.Filled.Delete, contentDescription = "حذف کالا", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(
                "موجودی: ${PersianNumberFormatter.toPersianDigits(line.availableStock.toString())}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = line.unitPrice,
                    onValueChange = { onUnitPriceChange(line.productId, it) },
                    label = { Text("قیمت واحد") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                QuantityStepper(
                    value = line.quantity,
                    max = line.availableStock,
                    onMinus = { onQuantityChange(line.productId, line.quantity - 1) },
                    onPlus = { onQuantityChange(line.productId, line.quantity + 1) },
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "مبلغ ردیف",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    line.lineSubtotal.toPersianDisplayString(),
                    style = MaterialTheme.typography.titleMedium,
                    color = if (line.lineSubtotal.isNegative) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                )
            }
            TextButton(onClick = { onItemDiscountClick(line.productId) }) {
                Text(if (line.itemDiscount.isZero) "تخفیف ردیف" else "تخفیف ردیف: ${line.itemDiscount.toPersianDisplayString()}")
            }
        }
    }
}

@Composable
private fun QuantityStepper(value: Int, max: Int, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Surface(onClick = onMinus, shape = CircleShape) {
            Icon(
                Icons.Filled.Remove,
                contentDescription = "کاهش تعداد",
                modifier = Modifier.padding(12.dp),
            )
        }
        Text(
            PersianNumberFormatter.toPersianDigits(value.toString()),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(horizontal = 14.dp),
        )
        Surface(onClick = onPlus, shape = CircleShape, enabled = value < max) {
            Icon(
                Icons.Filled.Add,
                contentDescription = "افزایش تعداد",
                modifier = Modifier.padding(12.dp),
            )
        }
    }
}

@Composable
private fun CostsCard(
    orderDiscount: Money,
    shippingProviderId: Long?,
    shippingProviders: List<Pair<String, Long>>,
    shippingPaymentType: ShippingPaymentType,
    shippingCharged: String,
    actualShippingCost: String,
    packagingCost: String,
    onOrderDiscountClick: () -> Unit,
    onShippingProviderChange: (Long?) -> Unit,
    onShippingPaymentTypeChange: (ShippingPaymentType) -> Unit,
    onShippingChargedChange: (String) -> Unit,
    onActualShippingCostChange: (String) -> Unit,
    onPackagingCostChange: (String) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("تخفیف سفارش", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                TextButton(onClick = onOrderDiscountClick) {
                    Text(if (orderDiscount.isZero) "اعمال تخفیف" else "تخفیف: ${orderDiscount.toPersianDisplayString()}")
                }
            }
            Text("ارسال", style = MaterialTheme.typography.titleSmall)
            if (shippingProviders.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(shippingProviders, key = { it.second }) { (name, id) ->
                        FilterChip(
                            selected = shippingProviderId == id,
                            onClick = { onShippingProviderChange(if (shippingProviderId == id) null else id) },
                            label = { Text(name) },
                        )
                    }
                }
            }
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(ShippingPaymentType.entries) { type ->
                    FilterChip(
                        selected = shippingPaymentType == type,
                        onClick = { onShippingPaymentTypeChange(type) },
                        label = { Text(type.persianLabel()) },
                    )
                }
            }
            OutlinedTextField(
                value = shippingCharged,
                onValueChange = onShippingChargedChange,
                label = { Text("هزینه ارسال دریافتی از مشتری (تومان)") },
                singleLine = true,
                enabled = shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            if (shippingPaymentType != ShippingPaymentType.CUSTOMER_PREPAID) {
                Text(
                    if (shippingPaymentType == ShippingPaymentType.COD) "در پس‌کرایه، مشتری هزینه ارسال را هنگام تحویل به پیک می‌پردازد"
                    else "فروشنده هزینه ارسال را می‌پردازد؛ مبلغی از مشتری دریافت نمی‌شود",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            OutlinedTextField(
                value = actualShippingCost,
                onValueChange = onActualShippingCostChange,
                label = { Text("هزینه واقعی ارسال (تومان)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            OutlinedTextField(
                value = packagingCost,
                onValueChange = onPackagingCostChange,
                label = { Text("هزینه بسته‌بندی (تومان)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
        }
    }
}

@Composable
private fun PaymentChannelCard(
    paymentMethods: List<Pair<String, Long>>,
    paymentMethodId: Long?,
    salesChannels: List<Pair<String, Long>>,
    salesChannelId: Long?,
    onPaymentMethodChange: (Long?) -> Unit,
    onSalesChannelChange: (Long?) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("روش پرداخت", style = MaterialTheme.typography.titleSmall)
            if (paymentMethods.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(paymentMethods, key = { it.second }) { (name, id) ->
                        FilterChip(
                            selected = paymentMethodId == id,
                            onClick = { onPaymentMethodChange(if (paymentMethodId == id) null else id) },
                            label = { Text(name) },
                        )
                    }
                }
            }
            Text("کانال فروش", style = MaterialTheme.typography.titleSmall)
            if (salesChannels.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(salesChannels, key = { it.second }) { (name, id) ->
                        FilterChip(
                            selected = salesChannelId == id,
                            onClick = { onSalesChannelChange(if (salesChannelId == id) null else id) },
                            label = { Text(name) },
                        )
                    }
                }
            }
        }
    }
}

/** Spec §14: clean customer-facing totals, sticky at the bottom. */
@Composable
private fun OrderFormSummary(state: OrderFormUiState, onSave: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SummaryRow("مبلغ کالاها", state.productSubtotal)
        if (state.orderDiscount.isPositive) {
            SummaryRow("تخفیف", Money(-state.orderDiscount.amountInToman), negative = true)
        }
        if (state.shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID && state.shippingChargedMoney.isPositive) {
            SummaryRow("هزینه ارسال دریافتی", state.shippingChargedMoney)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("مبلغ نهایی", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            Text(state.total.toPersianDisplayString(), style = MaterialTheme.typography.titleLarge)
        }
        Button(
            onClick = onSave,
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isSaving && state.lines.isNotEmpty(),
        ) {
            Text(if (state.isSaving) "در حال ثبت…" else "ثبت سفارش")
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: Money, negative: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            value.toPersianDisplayString(),
            style = MaterialTheme.typography.bodyMedium,
            color = if (negative) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
        )
    }
}

/** Percent-or-fixed discount editor (spec §7). */
@Composable
fun DiscountDialog(
    title: String,
    base: Money,
    current: Money,
    onConfirm: (Money) -> Unit,
    onDismiss: () -> Unit,
) {
    var isPercent by remember { mutableStateOf(false) }
    var value by remember { mutableStateOf(if (current.isZero) "" else current.amountInToman.toString()) }
    val parsed = value.toLongOrNull() ?: 0L
    val computed = if (isPercent) base.percentOf(parsed.toDouble()) else Money(parsed)
    // Money is not Comparable (KSP/Room value-class constraint) — clamp manually.
    val preview: Money = (if (computed > base) base else computed).coerceAtLeastZero()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = !isPercent,
                        onClick = { isPercent = false },
                        label = { Text("مبلغ (تومان)") },
                    )
                    FilterChip(
                        selected = isPercent,
                        onClick = { isPercent = true },
                        label = { Text("درصد") },
                    )
                }
                OutlinedTextField(
                    value = value,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text(if (isPercent) "درصد تخفیف" else "مبلغ تخفیف (تومان)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Text("پیش‌نمایش: ${preview.toPersianDisplayString()}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary)
                Text(
                    "مبلغ مبنا: ${base.toPersianDisplayString()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(preview) }) { Text("اعمال") }
        },
        dismissButton = {
            Row {
                if (current.isPositive) {
                    TextButton(onClick = { onConfirm(Money.ZERO) }) { Text("حذف تخفیف") }
                }
                TextButton(onClick = onDismiss) { Text("انصراف") }
            }
        },
    )
}
