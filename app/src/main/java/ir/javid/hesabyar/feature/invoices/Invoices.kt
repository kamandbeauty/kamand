@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.invoices

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.PictureAsPdf
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.core.model.InvoiceInput
import ir.javid.hesabyar.core.model.InvoiceKind
import ir.javid.hesabyar.core.model.InvoiceLineInput
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.data.local.dao.InvoiceListItem
import ir.javid.hesabyar.data.local.entity.CashAccountEntity
import ir.javid.hesabyar.data.local.entity.PartyEntity
import ir.javid.hesabyar.data.local.entity.ProductEntity
import ir.javid.hesabyar.domain.repository.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class InvoicesViewModel @Inject constructor(
    private val invoiceRepository: InvoiceRepository,
    productRepository: ProductRepository,
    partyRepository: PartyRepository,
    cashRepository: CashRepository,
    settingsRepository: SettingsRepository,
    private val pdfExporter: InvoicePdfExporter
) : ViewModel() {
    val sales = invoiceRepository.sales
    val purchases = invoiceRepository.purchases
    val products = productRepository.products
    val parties = partyRepository.parties
    val cashAccounts = cashRepository.accounts
    val settings = settingsRepository.settings
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    fun save(kind: InvoiceKind, input: InvoiceInput, done: () -> Unit) = viewModelScope.launch {
        val action = if (kind == InvoiceKind.SALE) invoiceRepository.createSale(input) else invoiceRepository.createPurchase(input)
        action.fold({ done() }, { _message.value = it.message ?: "ثبت فاکتور انجام نشد" })
    }
    fun cancel(kind: InvoiceKind, id: Long) = viewModelScope.launch {
        (if (kind == InvoiceKind.SALE) invoiceRepository.cancelSale(id) else invoiceRepository.cancelPurchase(id)).onFailure { _message.value = it.message ?: "ابطال فاکتور انجام نشد" }
    }
    fun exportPdf(kind: InvoiceKind, id: Long, onReady: (Uri) -> Unit) = viewModelScope.launch {
        val document = invoiceRepository.invoiceDocument(kind, id)
        if (document == null) _message.value = "جزئیات فاکتور پیدا نشد"
        else pdfExporter.export(document).fold(onSuccess = onReady, onFailure = { _message.value = it.message ?: "ساخت PDF ناموفق بود" })
    }
    fun dismissMessage() { _message.value = null }
}

@Composable
fun InvoicesScreen(kind: InvoiceKind, viewModel: InvoicesViewModel = hiltViewModel()) {
    val invoices by (if (kind == InvoiceKind.SALE) viewModel.sales else viewModel.purchases).collectAsStateWithLifecycle(initialValue = emptyList())
    val products by viewModel.products.collectAsStateWithLifecycle(initialValue = emptyList())
    val parties by viewModel.parties.collectAsStateWithLifecycle(initialValue = emptyList())
    val accounts by viewModel.cashAccounts.collectAsStateWithLifecycle(initialValue = emptyList())
    val settings by viewModel.settings.collectAsStateWithLifecycle(initialValue = ir.javid.hesabyar.data.local.entity.AppSettingsEntity())
    val message by viewModel.message.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val sharePdf: (Uri) -> Unit = { uri ->
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("invoice", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, "اشتراک‌گذاری فاکتور"))
    }
    var showEditor by remember { mutableStateOf(false) }
    var cancelling by remember { mutableStateOf<InvoiceListItem?>(null) }
    val title = if (kind == InvoiceKind.SALE) "فروش" else "خرید"
    AppScreen(title, floatingActionButton = { ExtendedFloatingActionButton(onClick = { showEditor = true }, icon = { Icon(Icons.Outlined.Add, null) }, text = { Text("فاکتور ${if (kind == InvoiceKind.SALE) "فروش" else "خرید"}") }) }) {
        if (invoices.isEmpty()) EmptyState("فاکتوری ثبت نشده", "با ثبت فاکتور، موجودی و حسابداری به‌صورت خودکار به‌روز می‌شود.")
        else LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 90.dp)) {
            items(invoices, key = { it.id }) { invoice ->
                SectionCard(onClick = { if (invoice.status == "FINAL") cancelling = invoice }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(invoice.invoiceNumber, fontWeight = FontWeight.Bold)
                            Text("${invoice.partyName ?: "فروش/خرید نقدی"} • ${PersianDate.format(invoice.dateEpochDay)}", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            MoneyText(invoice.totalAmount, style = MaterialTheme.typography.titleSmall)
                            if (invoice.balanceAmount > 0) Text("مانده: ${PersianNumbers.amount(invoice.balanceAmount)}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                            else Text(if (invoice.status == "FINAL") "تسویه" else "ابطال شده", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                            IconButton(onClick = { viewModel.exportPdf(kind, invoice.id, sharePdf) }) { Icon(Icons.Outlined.PictureAsPdf, "PDF و اشتراک‌گذاری") }
                        }
                    }
                }
            }
        }
    }
    if (showEditor) InvoiceEditor(kind, products, parties, accounts, settings.taxEnabled, settings.taxRate, onDismiss = { showEditor = false }, onSave = { input -> viewModel.save(kind, input) { showEditor = false } })
    cancelling?.let { invoice -> ConfirmDialog("ابطال فاکتور", "با ابطال، موجودی، مانده طرف حساب و سند حسابداری برگشت می‌خورند. ادامه می‌دهید؟", "ابطال فاکتور", onConfirm = { viewModel.cancel(kind, invoice.id); cancelling = null }, onDismiss = { cancelling = null }) }
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun InvoiceEditor(
    kind: InvoiceKind,
    products: List<ProductEntity>,
    parties: List<PartyEntity>,
    accounts: List<CashAccountEntity>,
    defaultTaxEnabled: Boolean,
    taxRate: Double,
    onDismiss: () -> Unit,
    onSave: (InvoiceInput) -> Unit
) {
    val lines = remember { mutableStateListOf<InvoiceLineInput>() }
    var selectedProductId by remember { mutableStateOf<Long?>(null) }
    var quantity by remember { mutableStateOf("1") }
    var selectedPartyId by remember { mutableStateOf<Long?>(null) }
    var selectedAccountId by remember { mutableStateOf<Long?>(null) }
    var paid by remember { mutableStateOf("") }
    var discount by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var productExpanded by remember { mutableStateOf(false) }
    var partyExpanded by remember { mutableStateOf(false) }
    var accountExpanded by remember { mutableStateOf(false) }
    var taxEnabled by remember { mutableStateOf(defaultTaxEnabled) }
    val subtotal = lines.sumOf { (it.quantity * it.unitPrice).toLong() }
    val discountAmount = PersianNumbers.parseDisplayedAmount(discount) ?: 0L
    val taxAmount = if (taxEnabled) ((subtotal - discountAmount).coerceAtLeast(0) * taxRate / 100).toLong() else 0L
    val total = (subtotal - discountAmount).coerceAtLeast(0) + taxAmount
    AlertDialog(onDismissRequest = onDismiss, title = { Text("فاکتور ${if (kind == InvoiceKind.SALE) "فروش" else "خرید"} جدید") }, text = {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("تاریخ: ${PersianDate.format(PersianDate.today())}", color = MaterialTheme.colorScheme.onSurfaceVariant)
            ExposedDropdownMenuBox(productExpanded, { productExpanded = !productExpanded }) {
                OutlinedTextField(products.firstOrNull { it.id == selectedProductId }?.name ?: "انتخاب کالا یا خدمت", {}, readOnly = true, label = { Text("کالا") }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(productExpanded) }, modifier = Modifier.menuAnchor().fillMaxWidth())
                ExposedDropdownMenu(productExpanded, { productExpanded = false }) { products.forEach { product -> DropdownMenuItem(text = { Text(product.name) }, onClick = { selectedProductId = product.id; productExpanded = false }) } }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FormTextField(quantity, { quantity = it }, "تعداد", Modifier.weight(1f))
                Button(onClick = {
                    val product = products.firstOrNull { it.id == selectedProductId }
                    val count = PersianNumbers.toEnglish(quantity).toDoubleOrNull()
                    if (product != null && count != null && count > 0) {
                        lines.add(InvoiceLineInput(product.id, count, if (kind == InvoiceKind.SALE) product.salePrice else product.purchasePrice))
                        selectedProductId = null; quantity = "1"
                    }
                }) { Text("افزودن") }
            }
            lines.forEachIndexed { index, line ->
                val product = products.firstOrNull { it.id == line.productId }
                Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = MaterialTheme.shapes.medium) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) { Text(product?.name ?: "کالا", fontWeight = FontWeight.SemiBold); Text("${PersianNumbers.quantity(line.quantity)} × ${PersianNumbers.amount(line.unitPrice)}", style = MaterialTheme.typography.labelSmall) }
                        IconButton(onClick = { lines.removeAt(index) }) { Icon(Icons.Outlined.DeleteOutline, "حذف ردیف") }
                    }
                }
            }
            HorizontalDivider()
            ExposedDropdownMenuBox(partyExpanded, { partyExpanded = !partyExpanded }) {
                OutlinedTextField(parties.firstOrNull { it.id == selectedPartyId }?.name ?: "طرف حساب (اختیاری برای تسویه نقدی)", {}, readOnly = true, label = { Text("طرف حساب") }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(partyExpanded) }, modifier = Modifier.menuAnchor().fillMaxWidth())
                ExposedDropdownMenu(partyExpanded, { partyExpanded = false }) { DropdownMenuItem(text = { Text("بدون طرف حساب") }, onClick = { selectedPartyId = null; partyExpanded = false }); parties.filter { if (kind == InvoiceKind.SALE) it.type != "SUPPLIER" else it.type != "CUSTOMER" }.forEach { party -> DropdownMenuItem(text = { Text(party.name) }, onClick = { selectedPartyId = party.id; partyExpanded = false }) } }
            }
            FormTextField(discount, { discount = it }, "تخفیف کل (تومان)")
            Row(verticalAlignment = Alignment.CenterVertically) { Switch(taxEnabled, { taxEnabled = it }); Spacer(Modifier.width(8.dp)); Text("مالیات ارزش افزوده (${PersianNumbers.toPersian(taxRate.toString())}٪)") }
            FormTextField(paid, { paid = it }, "مبلغ ${if (kind == InvoiceKind.SALE) "دریافتی" else "پرداختی"} (تومان)")
            if ((PersianNumbers.parseDisplayedAmount(paid) ?: 0) > 0) ExposedDropdownMenuBox(accountExpanded, { accountExpanded = !accountExpanded }) {
                OutlinedTextField(accounts.firstOrNull { it.id == selectedAccountId }?.name ?: "انتخاب صندوق یا بانک", {}, readOnly = true, label = { Text("حساب نقدی") }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(accountExpanded) }, modifier = Modifier.menuAnchor().fillMaxWidth())
                ExposedDropdownMenu(accountExpanded, { accountExpanded = false }) { accounts.forEach { account -> DropdownMenuItem(text = { Text(account.name) }, onClick = { selectedAccountId = account.id; accountExpanded = false }) } }
            }
            FormTextField(notes, { notes = it }, "توضیحات", singleLine = false)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("جمع فاکتور", fontWeight = FontWeight.Bold); MoneyText(total) }
        }
    }, confirmButton = { TextButton(onClick = {
        onSave(InvoiceInput(partyId = selectedPartyId, dateEpochDay = PersianDate.today(), lines = lines.toList(), discountAmount = discountAmount, taxEnabled = taxEnabled, taxRate = taxRate, paidAmount = PersianNumbers.parseDisplayedAmount(paid) ?: 0, cashAccountId = selectedAccountId, notes = notes))
    }) { Text("ثبت نهایی") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}
