@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.cash

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.data.local.entity.*
import ir.javid.hesabyar.domain.repository.CashRepository
import ir.javid.hesabyar.domain.repository.PartyRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CashViewModel @Inject constructor(private val repository: CashRepository, partyRepository: PartyRepository) : ViewModel() {
    val accounts = repository.accounts
    val parties = partyRepository.parties
    val receipts = repository.receipts
    val payments = repository.payments
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    private fun execute(task: suspend () -> Result<Long>, done: () -> Unit) = viewModelScope.launch { task().fold({ done() }, { _message.value = it.message ?: "عملیات ناموفق بود" }) }
    fun saveAccount(value: CashAccountEntity, done: () -> Unit) = execute({ repository.saveAccount(value) }, done)
    fun receive(value: ReceiptEntity, done: () -> Unit) = execute({ repository.receive(value) }, done)
    fun pay(value: PaymentEntity, done: () -> Unit) = execute({ repository.pay(value) }, done)
    fun expense(value: ExpenseEntity, done: () -> Unit) = execute({ repository.addExpense(value) }, done)
    fun income(value: IncomeEntity, done: () -> Unit) = execute({ repository.addIncome(value) }, done)
    fun transfer(value: CashTransferEntity, done: () -> Unit) = execute({ repository.transfer(value) }, done)
    fun dismissMessage() { _message.value = null }
}

private enum class CashDialog { ACCOUNT, RECEIPT, PAYMENT, EXPENSE, INCOME, TRANSFER }

@Composable
fun CashScreen(viewModel: CashViewModel = hiltViewModel()) {
    val accounts by viewModel.accounts.collectAsStateWithLifecycle(initialValue = emptyList())
    val parties by viewModel.parties.collectAsStateWithLifecycle(initialValue = emptyList())
    val receipts by viewModel.receipts.collectAsStateWithLifecycle(initialValue = emptyList())
    val payments by viewModel.payments.collectAsStateWithLifecycle(initialValue = emptyList())
    val message by viewModel.message.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }
    var dialog by remember { mutableStateOf<CashDialog?>(null) }
    AppScreen("دریافت و پرداخت", actions = { IconButton(onClick = { dialog = CashDialog.TRANSFER }) { Icon(Icons.Outlined.SwapHoriz, "انتقال وجه") } }, floatingActionButton = { ExtendedFloatingActionButton(onClick = { dialog = if (tab == 0) CashDialog.ACCOUNT else if (tab == 1) CashDialog.RECEIPT else CashDialog.PAYMENT }, icon = { Icon(Icons.Outlined.Add, null) }, text = { Text("ثبت جدید") }) }) {
        TabRow(selectedTabIndex = tab) {
            listOf("حساب‌ها", "دریافت", "پرداخت").forEachIndexed { index, label -> Tab(selected = tab == index, onClick = { tab = index }, text = { Text(label) }) }
        }
        when (tab) {
            0 -> AccountsList(accounts, onAddExpense = { dialog = CashDialog.EXPENSE }, onAddIncome = { dialog = CashDialog.INCOME })
            1 -> TransactionsList(receipts.map { "دریافت" to it.amount to it.dateEpochDay }, empty = "دریافتی ثبت نشده")
            else -> TransactionsList(payments.map { "پرداخت" to it.amount to it.dateEpochDay }, empty = "پرداختی ثبت نشده")
        }
    }
    when (dialog) {
        CashDialog.ACCOUNT -> CashAccountEditor(onDismiss = { dialog = null }, onSave = { viewModel.saveAccount(it) { dialog = null } })
        CashDialog.RECEIPT -> CashTransactionEditor("دریافت از مشتری", accounts, parties, onDismiss = { dialog = null }) { party, account, amount, note -> viewModel.receive(ReceiptEntity(partyId = party, cashAccountId = account, amount = amount, dateEpochDay = PersianDate.today(), note = note)) { dialog = null } }
        CashDialog.PAYMENT -> CashTransactionEditor("پرداخت به فروشنده", accounts, parties, onDismiss = { dialog = null }) { party, account, amount, note -> viewModel.pay(PaymentEntity(partyId = party, cashAccountId = account, amount = amount, dateEpochDay = PersianDate.today(), note = note)) { dialog = null } }
        CashDialog.EXPENSE -> IncomeExpenseEditor(false, accounts, onDismiss = { dialog = null }) { title, account, amount, note -> viewModel.expense(ExpenseEntity(title = title, cashAccountId = account, amount = amount, dateEpochDay = PersianDate.today(), note = note)) { dialog = null } }
        CashDialog.INCOME -> IncomeExpenseEditor(true, accounts, onDismiss = { dialog = null }) { title, account, amount, note -> viewModel.income(IncomeEntity(title = title, cashAccountId = account, amount = amount, dateEpochDay = PersianDate.today(), note = note)) { dialog = null } }
        CashDialog.TRANSFER -> TransferEditor(accounts, onDismiss = { dialog = null }) { from, to, amount, note -> viewModel.transfer(CashTransferEntity(fromAccountId = from, toAccountId = to, amount = amount, dateEpochDay = PersianDate.today(), note = note)) { dialog = null } }
        null -> Unit
    }
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun AccountsList(accounts: List<CashAccountEntity>, onAddExpense: () -> Unit, onAddIncome: () -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 90.dp)) {
        if (accounts.isEmpty()) item { EmptyState("حسابی ثبت نشده", "یک صندوق یا حساب بانکی اضافه کنید.") }
        items(accounts, key = { it.id }) { account -> SectionCard { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Column { Text(account.name, fontWeight = FontWeight.Bold); Text(if (account.type == "CASH") "صندوق" else "بانک", color = MaterialTheme.colorScheme.onSurfaceVariant) }; MoneyText(account.balance) } } }
        item { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton(onClick = onAddExpense, Modifier.weight(1f)) { Text("ثبت هزینه") }; OutlinedButton(onClick = onAddIncome, Modifier.weight(1f)) { Text("ثبت درآمد") } } }
    }
}

@Composable
private fun TransactionsList(rows: List<Pair<Pair<String, Long>, Long>>, empty: String) {
    if (rows.isEmpty()) EmptyState(empty, "از دکمه ثبت جدید استفاده کنید.")
    else LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) { items(rows) { row -> SectionCard { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Column { Text(row.first.first, fontWeight = FontWeight.Bold); Text(PersianDate.format(row.second), color = MaterialTheme.colorScheme.onSurfaceVariant) }; MoneyText(row.first.second) } } } }
}

@Composable
private fun CashAccountEditor(onDismiss: () -> Unit, onSave: (CashAccountEntity) -> Unit) {
    var name by remember { mutableStateOf("") }; var opening by remember { mutableStateOf("") }; var bank by remember { mutableStateOf("") }; var type by remember { mutableStateOf("CASH") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("صندوق یا بانک جدید") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(name, { name = it }, "نام حساب"); SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) { listOf("CASH" to "صندوق", "BANK" to "بانک").forEachIndexed { i, pair -> SegmentedButton(type == pair.first, { type = pair.first }, SegmentedButtonDefaults.itemShape(i, 2)) { Text(pair.second) } } }; if (type == "BANK") FormTextField(bank, { bank = it }, "نام بانک"); FormTextField(opening, { opening = it }, "مانده اولیه (تومان)") } }, confirmButton = { TextButton(onClick = { onSave(CashAccountEntity(name = name, type = type, bankName = bank, openingBalance = PersianNumbers.parseDisplayedAmount(opening) ?: 0)) }) { Text("ذخیره") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun CashTransactionEditor(title: String, accounts: List<CashAccountEntity>, parties: List<PartyEntity>, onDismiss: () -> Unit, onSave: (Long?, Long, Long, String) -> Unit) {
    var partyId by remember { mutableStateOf<Long?>(null) }; var accountId by remember { mutableStateOf<Long?>(null) }; var amount by remember { mutableStateOf("") }; var note by remember { mutableStateOf("") }; var partyExpanded by remember { mutableStateOf(false) }; var accountExpanded by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(title) }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { DropdownSelect("طرف حساب", parties.firstOrNull { it.id == partyId }?.name ?: "بدون طرف حساب", partyExpanded, { partyExpanded = it }) { DropdownMenuItem(text = { Text("بدون طرف حساب") }, onClick = { partyId = null; partyExpanded = false }); parties.forEach { party -> DropdownMenuItem(text = { Text(party.name) }, onClick = { partyId = party.id; partyExpanded = false }) } }; DropdownSelect("صندوق یا بانک", accounts.firstOrNull { it.id == accountId }?.name ?: "انتخاب حساب", accountExpanded, { accountExpanded = it }) { accounts.forEach { account -> DropdownMenuItem(text = { Text(account.name) }, onClick = { accountId = account.id; accountExpanded = false }) } }; FormTextField(amount, { amount = it }, "مبلغ (تومان)"); FormTextField(note, { note = it }, "توضیحات") } }, confirmButton = { TextButton(onClick = { accountId?.let { onSave(partyId, it, PersianNumbers.parseDisplayedAmount(amount) ?: 0, note) } }) { Text("ثبت") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun IncomeExpenseEditor(income: Boolean, accounts: List<CashAccountEntity>, onDismiss: () -> Unit, onSave: (String, Long, Long, String) -> Unit) {
    var title by remember { mutableStateOf("") }; var accountId by remember { mutableStateOf<Long?>(null) }; var amount by remember { mutableStateOf("") }; var note by remember { mutableStateOf("") }; var expanded by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (income) "ثبت درآمد" else "ثبت هزینه") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(title, { title = it }, "عنوان"); DropdownSelect("صندوق یا بانک", accounts.firstOrNull { it.id == accountId }?.name ?: "انتخاب حساب", expanded, { expanded = it }) { accounts.forEach { account -> DropdownMenuItem(text = { Text(account.name) }, onClick = { accountId = account.id; expanded = false }) } }; FormTextField(amount, { amount = it }, "مبلغ (تومان)"); FormTextField(note, { note = it }, "توضیحات") } }, confirmButton = { TextButton(onClick = { accountId?.let { onSave(title, it, PersianNumbers.parseDisplayedAmount(amount) ?: 0, note) } }) { Text("ثبت") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun TransferEditor(accounts: List<CashAccountEntity>, onDismiss: () -> Unit, onSave: (Long, Long, Long, String) -> Unit) {
    var from by remember { mutableStateOf<Long?>(null) }; var to by remember { mutableStateOf<Long?>(null) }; var amount by remember { mutableStateOf("") }; var note by remember { mutableStateOf("") }; var fromExpanded by remember { mutableStateOf(false) }; var toExpanded by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("انتقال وجه") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { DropdownSelect("از حساب", accounts.firstOrNull { it.id == from }?.name ?: "انتخاب مبدا", fromExpanded, { fromExpanded = it }) { accounts.forEach { a -> DropdownMenuItem(text = { Text(a.name) }, onClick = { from = a.id; fromExpanded = false }) } }; DropdownSelect("به حساب", accounts.firstOrNull { it.id == to }?.name ?: "انتخاب مقصد", toExpanded, { toExpanded = it }) { accounts.forEach { a -> DropdownMenuItem(text = { Text(a.name) }, onClick = { to = a.id; toExpanded = false }) } }; FormTextField(amount, { amount = it }, "مبلغ (تومان)"); FormTextField(note, { note = it }, "توضیحات") } }, confirmButton = { TextButton(onClick = { if (from != null && to != null) onSave(from!!, to!!, PersianNumbers.parseDisplayedAmount(amount) ?: 0, note) }) { Text("انتقال") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun DropdownSelect(label: String, value: String, expanded: Boolean, onExpandedChange: (Boolean) -> Unit, menu: @Composable ColumnScope.() -> Unit) {
    ExposedDropdownMenuBox(expanded, onExpandedChange) { OutlinedTextField(value, {}, readOnly = true, label = { Text(label) }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) }, modifier = Modifier.menuAnchor().fillMaxWidth()); ExposedDropdownMenu(expanded, { onExpandedChange(false) }, content = menu) }
}
