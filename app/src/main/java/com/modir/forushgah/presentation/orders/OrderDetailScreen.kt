package com.modir.forushgah.presentation.orders

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.DateTimeFormatter
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.common.isZero
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.data.repository.ReturnItemDraft
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.ShippingPaymentType

@Composable
fun OrderDetailRoute(
    onBack: () -> Unit,
    viewModel: OrderDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    val event by viewModel.event.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    var showPaymentDialog by remember { mutableStateOf(false) }
    var showRefundDialog by remember { mutableStateOf(false) }
    var showReturnDialog by remember { mutableStateOf(false) }
    var showCancelConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(event) {
        when (val e = event) {
            is com.modir.forushgah.presentation.orders.OrderDetailEvent.Success -> snackbarHostState.showSnackbar(e.message)
            is com.modir.forushgah.presentation.orders.OrderDetailEvent.Error -> snackbarHostState.showSnackbar(e.message)
            null -> Unit
        }
        viewModel.consumeEvent()
    }

    OrderDetailScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        showPaymentDialog = showPaymentDialog,
        showRefundDialog = showRefundDialog,
        showReturnDialog = showReturnDialog,
        showCancelConfirm = showCancelConfirm,
        onBack = onBack,
        onStatusChange = viewModel::setStatus,
        onCancelClick = { showCancelConfirm = true },
        onPaymentClick = { showPaymentDialog = true },
        onRecordPayment = { amount, method, methodId, reference, note ->
            viewModel.recordPayment(amount, method, methodId, reference, note)
            showPaymentDialog = false
        },
        onRefundClick = { showRefundDialog = true },
        onRecordRefund = { amount, method, reason, note ->
            viewModel.createRefund(amount, method, reason, note)
            showRefundDialog = false
        },
        onReturnClick = { showReturnDialog = true },
        onCreateReturn = { items, reason, shippingCost, packagingLost, restock ->
            viewModel.createReturn(items, reason, shippingCost, packagingLost, restock)
            showReturnDialog = false
        },
        onReturnStatusChange = viewModel::setReturnStatus,
        onDismissDialog = {
            showPaymentDialog = false
            showRefundDialog = false
            showReturnDialog = false
            showCancelConfirm = false
        },
        onConfirmCancel = {
            showCancelConfirm = false
            viewModel.cancel()
        },
    )
}

/** Spec §17: detailed but clean order page. */
@Composable
fun OrderDetailScreen(
    state: OrderDetailUiState,
    snackbarHostState: SnackbarHostState,
    showPaymentDialog: Boolean,
    showRefundDialog: Boolean,
    showReturnDialog: Boolean,
    showCancelConfirm: Boolean,
    onBack: () -> Unit,
    onStatusChange: (OrderStatus) -> Unit,
    onCancelClick: () -> Unit,
    onPaymentClick: () -> Unit,
    onRecordPayment: (Money, String, Long?, String?, String?) -> Unit,
    onRefundClick: () -> Unit,
    onRecordRefund: (Money, String, String, String?) -> Unit,
    onReturnClick: () -> Unit,
    onCreateReturn: (List<ReturnItemDraft>, ReturnReason, Money, Money, Boolean) -> Unit,
    onReturnStatusChange: (Long, ReturnStatus) -> Unit,
    onDismissDialog: () -> Unit,
    onConfirmCancel: () -> Unit,
) {
    val detail = state.detail

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("سفارش") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
                actions = {
                    if (detail != null) {
                        StatusMenu(current = detail.order.status, onChange = onStatusChange)
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                detail == null -> EmptyState(
                    title = "سفارش یافت نشد",
                    subtitle = "این سفارش دیگر در دسترس نیست",
                    ctaLabel = "بازگشت",
                    onCtaClick = onBack,
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item { HeaderCard(detail = detail) }
                    item { CustomerCard(detail) }
                    item { Text("کالاهای سفارش", style = MaterialTheme.typography.titleMedium) }
                    items(detail.items, key = { it.item.id }) { row ->
                        OrderItemCard(
                            name = row.productName,
                            quantity = row.item.quantity,
                            unitPrice = row.item.unitSellingPrice,
                            discount = row.item.discount,
                            subtotal = Money(row.item.unitSellingPrice.amountInToman * row.item.quantity - row.item.discount.amountInToman),
                        )
                    }
                    item { ShippingCard(detail = detail, providers = state.shippingProviders) }
                    item {
                        PaymentCard(
                            total = detail.total,
                            paid = detail.totalPaid,
                            remaining = detail.remaining,
                            payments = detail.payments,
                            canPay = detail.remaining.isPositive && detail.order.status != OrderStatus.CANCELLED,
                            onPaymentClick = onPaymentClick,
                        )
                    }
                    item {
                        ReturnsSection(
                            detail = detail,
                            canCreate = detail.order.status != OrderStatus.CANCELLED &&
                                detail.order.status != OrderStatus.RETURNED,
                            onReturnClick = onReturnClick,
                            onReturnStatusChange = onReturnStatusChange,
                        )
                    }
                    if (detail.refunds.isNotEmpty()) {
                        item { RefundsCard(refunds = detail.refunds, onRefundClick = onRefundClick, canRefund = (detail.totalPaid - detail.totalRefunded).isPositive) }
                    }
                    detail.order.notes?.let { notes ->
                        item {
                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("یادداشت", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(notes, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                    }
                    if (detail.order.status != OrderStatus.CANCELLED && detail.order.status != OrderStatus.RETURNED) {
                        item {
                            TextButton(onClick = onCancelClick) {
                                Text("لغو سفارش", color = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
        }
    }

    if (detail != null) {
        if (showPaymentDialog) {
            PaymentDialog(
                remaining = detail.remaining,
                paymentMethods = state.paymentMethods,
                onConfirm = onRecordPayment,
                onDismiss = onDismissDialog,
            )
        }
        if (showRefundDialog) {
            RefundDialog(
                refundable = detail.totalPaid - detail.totalRefunded,
                paymentMethods = state.paymentMethods,
                onConfirm = onRecordRefund,
                onDismiss = onDismissDialog,
            )
        }
        if (showReturnDialog) {
            ReturnDialog(
                detail = detail,
                onConfirm = onCreateReturn,
                onDismiss = onDismissDialog,
            )
        }
        if (showCancelConfirm) {
            AlertDialog(
                onDismissRequest = onDismissDialog,
                title = { Text("لغو سفارش") },
                text = {
                    Text("سفارش لغو می‌شود؛ اگر موجودی کالاهای آن کم شده بود، به‌صورت خودکار برمی‌گردد.")
                },
                confirmButton = { TextButton(onClick = onConfirmCancel) { Text("لغو سفارش") } },
                dismissButton = { TextButton(onClick = onDismissDialog) { Text("انصراف") } },
            )
        }
    }
}

@Composable
private fun StatusMenu(current: OrderStatus, onChange: (OrderStatus) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Filled.ArrowDropDown, contentDescription = "تغییر وضعیت")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            OrderStatus.entries.forEach { status ->
                DropdownMenuItem(
                    text = { Text(status.persianLabel() + if (status == current) " (فعلی)" else "") },
                    onClick = {
                        expanded = false
                        if (status != current) onChange(status)
                    },
                )
            }
        }
    }
}

@Composable
private fun HeaderCard(detail: com.modir.forushgah.data.repository.OrderDetail) {
    val order = detail.order
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(order.orderNumber, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                StatusBadge(status = order.status)
            }
            Text(DateTimeFormatter.dateTime(order.orderDate), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("مبلغ نهایی", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                Text(detail.total.toPersianDisplayString(), style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

@Composable
private fun CustomerCard(detail: com.modir.forushgah.data.repository.OrderDetail) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("مشتری", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(detail.customerName ?: "بدون مشتری", style = MaterialTheme.typography.titleMedium)
            detail.customerMobile?.let {
                Text(PersianNumberFormatter.toPersianDigits(it), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun OrderItemCard(name: String, quantity: Int, unitPrice: Money, discount: Money, subtotal: Money) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(name, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                Text(
                    "×${PersianNumberFormatter.toPersianDigits(quantity.toString())}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                "قیمت واحد: ${unitPrice.toPersianDisplayString()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!discount.isZero) {
                Text(
                    "تخفیف ردیف: ${discount.toPersianDisplayString()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("جمع ردیف", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                Text(subtotal.toPersianDisplayString(), style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
private fun ShippingCard(
    detail: com.modir.forushgah.data.repository.OrderDetail,
    providers: List<com.modir.forushgah.domain.model.ShippingProvider>,
) {
    val order = detail.order
    val providerName = providers.firstOrNull { it.id == order.shippingProviderId }?.name
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("ارسال", style = MaterialTheme.typography.titleMedium)
            InfoRow("پیک", providerName ?: "—")
            InfoRow("نحوه پرداخت ارسال", order.shippingPaymentType.persianLabel())
            InfoRow("دریافتی از مشتری", order.shippingChargedToCustomer.toPersianDisplayString())
            InfoRow("هزینه واقعی ارسال", order.actualShippingCost.toPersianDisplayString())
            InfoRow("هزینه بسته‌بندی", order.packagingCost.toPersianDisplayString())
            // Phase 3.1: the tracking data saved from «کدهای رهگیری ارسال»
            order.trackingCode?.let { InfoRow("کد رهگیری", it) }
            order.shippedAt?.let { InfoRow("تاریخ ارسال", com.modir.forushgah.core.date.JalaliDateFormatter.formatJalali(it)) }
        }
    }
}

@Composable
private fun PaymentCard(
    total: Money,
    paid: Money,
    remaining: Money,
    payments: List<com.modir.forushgah.data.local.entity.PaymentEntity>,
    canPay: Boolean,
    onPaymentClick: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("پرداخت", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                if (canPay) {
                    TextButton(onClick = onPaymentClick) {
                        Icon(Icons.Filled.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("ثبت پرداخت")
                    }
                }
            }
            InfoRow("مجموع", total.toPersianDisplayString())
            InfoRow("پرداخت‌شده", paid.toPersianDisplayString())
            InfoRow("باقی‌مانده", remaining.toPersianDisplayString())
            if (payments.isNotEmpty()) {
                Divider()
                payments.forEach { payment ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(payment.method, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                DateTimeFormatter.dateTime(payment.paidAt) + payment.reference?.let { " — کد: $it" }.orEmpty(),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(payment.amount.toPersianDisplayString(), style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}

@Composable
private fun ReturnsSection(
    detail: com.modir.forushgah.data.repository.OrderDetail,
    canCreate: Boolean,
    onReturnClick: () -> Unit,
    onReturnStatusChange: (Long, ReturnStatus) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("مرجوعی‌ها", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                if (canCreate) {
                    TextButton(onClick = onReturnClick) {
                        Icon(Icons.Filled.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("ثبت مرجوعی")
                    }
                }
            }
            if (detail.returns.isEmpty()) {
                Text("مرجوعی‌ای ثبت نشده", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            detail.returns.forEach { returnRow ->
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            returnRow.reason.persianLabel(),
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                        )
                        ReturnStatusBadge(status = returnRow.status, onChange = onReturnStatusChange, returnId = returnRow.id)
                    }
                    Text(DateTimeFormatter.dateTime(returnRow.date), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (returnRow.returnShippingCost.isPositive || returnRow.packagingCostLost.isPositive) {
                        Text(
                            "هزینه مرجوعی: ${(returnRow.returnShippingCost + returnRow.packagingCostLost).toPersianDisplayString()}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
                Divider()
            }
        }
    }
}

@Composable
private fun ReturnStatusBadge(returnId: Long, status: ReturnStatus, onChange: (Long, ReturnStatus) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Surface(onClick = { expanded = true }, shape = MaterialTheme.shapes.small) {
            Text(
                status.persianLabel(),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ReturnStatus.entries.forEach { s ->
                DropdownMenuItem(
                    text = { Text(s.persianLabel()) },
                    onClick = {
                        expanded = false
                        if (s != status) onChange(returnId, s)
                    },
                )
            }
        }
    }
}

@Composable
private fun RefundsCard(
    refunds: List<com.modir.forushgah.data.local.entity.RefundEntity>,
    onRefundClick: () -> Unit,
    canRefund: Boolean,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("استردادها", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                if (canRefund) TextButton(onClick = onRefundClick) { Text("ثبت استرداد") }
            }
            refunds.forEach { refund ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("${refund.method} — ${refund.reason.orEmpty()}", style = MaterialTheme.typography.bodyMedium)
                        Text(DateTimeFormatter.dateTime(refund.date), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text("−${refund.amount.toPersianDisplayString(includeCurrencySuffix = false)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

// ---------- dialogs ----------

@Composable
private fun PaymentDialog(
    remaining: Money,
    paymentMethods: List<com.modir.forushgah.domain.model.PaymentMethod>,
    onConfirm: (Money, String, Long?, String?, String?) -> Unit,
    onDismiss: () -> Unit,
) {
    var amount by remember { mutableStateOf(remaining.amountInToman.toString()) }
    var methodId by remember { mutableStateOf<Long?>(null) }
    var methodLabel by remember { mutableStateOf("نقدی") }
    var reference by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    val parsed = amount.toLongOrNull() ?: 0L

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("ثبت پرداخت") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("مانده: ${remaining.toPersianDisplayString()}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (paymentMethods.isNotEmpty()) {
                    LazyRowCompact(paymentMethods.map { it.name to it.id }) { (name, id) ->
                        FilterChip(
                            selected = methodId == id,
                            onClick = {
                                methodId = if (methodId == id) null else id
                                methodLabel = if (methodId == id) name else "نقدی"
                            },
                            label = { Text(name) },
                        )
                    }
                }
                OutlinedTextField(
                    value = amount,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text("مبلغ پرداخت (تومان)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = reference,
                    onValueChange = { reference = it },
                    label = { Text("شماره پیگیری / کد ادا (اختیاری)") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("یادداشت (اختیاری)") },
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            Button(onClick = { onConfirm(Money(parsed), methodLabel, methodId, reference.ifBlank { null }, note.ifBlank { null }) }, enabled = parsed > 0) {
                Text("ثبت")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

/** Small LazyRow for chips inside dialogs. */
@Composable
private fun LazyRowCompact(items: List<Pair<String, Long>>, content: @Composable (Pair<String, Long>) -> Unit) {
    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        androidx.compose.foundation.lazy.items(items, key = { it.second }) { item -> content(item) }
    }
}

@Composable
private fun RefundDialog(
    refundable: Money,
    paymentMethods: List<com.modir.forushgah.domain.model.PaymentMethod>,
    onConfirm: (Money, String, String, String?) -> Unit,
    onDismiss: () -> Unit,
) {
    var amount by remember { mutableStateOf(refundable.amountInToman.toString()) }
    var method by remember { mutableStateOf("کارت بانکی") }
    var reason by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    val parsed = amount.toLongOrNull() ?: 0L

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("ثبت استرداد") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("قابل استرداد: ${refundable.toPersianDisplayString()}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (paymentMethods.isNotEmpty()) {
                    LazyRowCompact(paymentMethods.map { it.name to it.id }) { (name, _) ->
                        FilterChip(selected = method == name, onClick = { method = name }, label = { Text(name) })
                    }
                }
                OutlinedTextField(
                    value = amount,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text("مبلغ استرداد (تومان)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = reason,
                    onValueChange = { reason = it },
                    label = { Text("دلیل") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("یادداشت (اختیاری)") },
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            Button(onClick = { onConfirm(Money(parsed), method, reason.ifBlank { "سایر" }, note.ifBlank { null }) }, enabled = parsed > 0) {
                Text("ثبت استرداد")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun ReturnDialog(
    detail: com.modir.forushgah.data.repository.OrderDetail,
    onConfirm: (List<ReturnItemDraft>, ReturnReason, Money, Money, Boolean) -> Unit,
    onDismiss: () -> Unit,
) {
    val returnedByProduct = detail.returnedQuantityByProduct
    // editable quantities per line
    val returnableLines = detail.items.filter { row ->
        (row.item.quantity - (returnedByProduct[row.item.productId] ?: 0)) > 0
    }
    var quantities by remember { mutableStateOf<Map<Long, Int>>(emptyMap()) }
    var reason by remember { mutableStateOf(ReturnReason.OTHER) }
    var shippingCost by remember { mutableStateOf("") }
    var packagingLost by remember { mutableStateOf("") }
    var restock by remember { mutableStateOf(true) }

    fun quantityOf(productId: Long): Int = quantities[productId] ?: 0

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("ثبت مرجوعی") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (returnableLines.isEmpty()) {
                    Text("برای این سفارش کالایی باقی‌مانده برای مرجوعی نیست", style = MaterialTheme.typography.bodyMedium)
                }
                returnableLines.forEach { row ->
                    val line = row.item
                    val maxQty = line.quantity - (returnedByProduct[line.productId] ?: 0)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "${row.productName} (حداکثر ${PersianNumberFormatter.toPersianDigits(maxQty.toString())})",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                        )
                        OutlinedTextField(
                            value = quantityOf(line.productId).let { if (it == 0) "" else it.toString() },
                            onValueChange = { v ->
                                val n = v.filter { c -> c.isDigit() }.toIntOrNull() ?: 0
                                quantities = quantities + (line.productId to n.coerceIn(0, maxQty))
                            },
                            label = { Text("تعداد") },
                            singleLine = true,
                            modifier = Modifier.width(96.dp),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                    }
                }
                LazyRowCompact(ReturnReason.entries.map { it to it.hashCode().toLong() }) { (r, _) ->
                    FilterChip(selected = reason == r, onClick = { reason = r }, label = { Text(r.persianLabel()) })
                }
                OutlinedTextField(
                    value = shippingCost,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text("هزینه ارسال مرجوعی (تومان)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = packagingLost,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text("بسته‌بندی تلف‌شده (تومان)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("بازگشت به موجودی انبار", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    Switch(checked = restock, onCheckedChange = { restock = it })
                }
            }
        },
        confirmButton = {
            val items = returnableLines
                .map { ReturnItemDraft(it.item.productId, quantityOf(it.item.productId)) }
                .filter { it.quantity > 0 }
            Button(
                onClick = {
                    onConfirm(
                        items,
                        reason,
                        Money(shippingCost.toLongOrNull() ?: 0),
                        Money(packagingLost.toLongOrNull() ?: 0),
                        restock,
                    )
                },
                enabled = items.isNotEmpty(),
            ) {
                Text("ثبت مرجوعی")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
