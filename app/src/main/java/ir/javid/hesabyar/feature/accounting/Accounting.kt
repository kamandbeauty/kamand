@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.accounting

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
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
import ir.javid.hesabyar.core.model.JournalInput
import ir.javid.hesabyar.core.model.JournalLineInput
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.data.local.dao.AccountBalanceRow
import ir.javid.hesabyar.data.local.dao.JournalLineRow
import ir.javid.hesabyar.data.local.dao.JournalListItem
import ir.javid.hesabyar.data.local.entity.AccountEntity
import ir.javid.hesabyar.domain.repository.AccountingRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AccountingViewModel @Inject constructor(private val repository: AccountingRepository) : ViewModel() {
    val accounts = repository.accounts
    val entries = repository.entries
    val trialBalance = repository.trialBalance
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    fun saveEntry(value: JournalInput, done: () -> Unit) = viewModelScope.launch { repository.saveManualEntry(value).fold({ done() }, { _message.value = it.message ?: "ثبت سند ناموفق بود" }) }
    fun saveAccount(value: AccountEntity, done: () -> Unit) = viewModelScope.launch { repository.saveAccount(value).fold({ done() }, { _message.value = it.message ?: "ذخیره حساب ناموفق بود" }) }
    fun deleteManual(id: Long) = viewModelScope.launch { repository.deleteManualEntry(id).onFailure { _message.value = it.message } }
    fun ledger(accountId: Long) = repository.ledger(accountId, PersianDate.startOfMonth(PersianDate.today()), PersianDate.today())
    fun dismissMessage() { _message.value = null }
}

@Composable
fun AccountingScreen(viewModel: AccountingViewModel = hiltViewModel()) {
    val accounts by viewModel.accounts.collectAsStateWithLifecycle(initialValue = emptyList())
    val entries by viewModel.entries.collectAsStateWithLifecycle(initialValue = emptyList())
    val trial by viewModel.trialBalance.collectAsStateWithLifecycle(initialValue = emptyList())
    val message by viewModel.message.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }
    var showEntry by remember { mutableStateOf(false) }
    var showAccount by remember { mutableStateOf(false) }
    var delete by remember { mutableStateOf<JournalListItem?>(null) }
    var ledgerAccount by remember { mutableStateOf<AccountEntity?>(null) }
    AppScreen("حسابداری", actions = { TextButton(onClick = { showAccount = true }) { Text("حساب جدید") } }, floatingActionButton = { ExtendedFloatingActionButton(onClick = { showEntry = true }, icon = { Icon(Icons.Outlined.Add, null) }, text = { Text("سند دستی") }) }) {
        TabRow(tab) { listOf("اسناد", "تراز آزمایشی", "کدینگ").forEachIndexed { i, label -> Tab(tab == i, { tab = i }, text = { Text(label) }) } }
        when (tab) {
            0 -> JournalList(entries, onDelete = { delete = it })
            1 -> TrialBalanceList(trial)
            else -> AccountList(accounts, onSelect = { ledgerAccount = it })
        }
    }
    if (showEntry) ManualEntryEditor(accounts, onDismiss = { showEntry = false }, onSave = { viewModel.saveEntry(it) { showEntry = false } })
    if (showAccount) AccountEditor(onDismiss = { showAccount = false }, onSave = { viewModel.saveAccount(it) { showAccount = false } })
    ledgerAccount?.let { LedgerDialog(it, viewModel.ledger(it.id), onDismiss = { ledgerAccount = null }) }
    delete?.let { ConfirmDialog("حذف سند", "تنها اسناد دستی قابل حذف هستند. آیا ادامه می‌دهید؟", "حذف", { viewModel.deleteManual(it.id); delete = null }, { delete = null }) }
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun JournalList(entries: List<JournalListItem>, onDelete: (JournalListItem) -> Unit) {
    if (entries.isEmpty()) EmptyState("سندی ثبت نشده", "اسناد فروش، خرید و دریافت/پرداخت به‌صورت خودکار اینجا ظاهر می‌شوند.")
    else LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 90.dp)) { items(entries, key = { it.id }) { entry -> SectionCard(onClick = { if (entry.sourceType == "MANUAL") onDelete(entry) }) { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Column(Modifier.weight(1f)) { Text(entry.entryNumber, fontWeight = FontWeight.Bold); Text("${entry.description} • ${PersianDate.format(entry.dateEpochDay)}", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }; Column(horizontalAlignment = Alignment.End) { Text(entry.sourceType, style = MaterialTheme.typography.labelSmall); Text("بدهکار: ${PersianNumbers.amount(entry.debit)}", style = MaterialTheme.typography.labelSmall) } } } } }
}

@Composable
private fun TrialBalanceList(rows: List<AccountBalanceRow>) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp), contentPadding = PaddingValues(bottom = 24.dp)) { items(rows, key = { it.accountId }) { row -> SectionCard { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Column(Modifier.weight(1f)) { Text("${row.code} - ${row.name}", fontWeight = FontWeight.SemiBold); Text(accountTypeName(row.type), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }; Column(horizontalAlignment = Alignment.End) { Text("بد: ${PersianNumbers.amount(row.debit)}", style = MaterialTheme.typography.labelSmall); Text("بس: ${PersianNumbers.amount(row.credit)}", style = MaterialTheme.typography.labelSmall) } } } } }
}

@Composable
private fun AccountList(accounts: List<AccountEntity>, onSelect: (AccountEntity) -> Unit) { LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) { items(accounts, key = { it.id }) { account -> ListItem(headlineContent = { Text("${account.code} - ${account.name}") }, supportingContent = { Text(accountTypeName(account.type)) }, modifier = Modifier.clickable { onSelect(account) }); HorizontalDivider() } } }

@Composable
private fun ManualEntryEditor(accounts: List<AccountEntity>, onDismiss: () -> Unit, onSave: (JournalInput) -> Unit) {
    var description by remember { mutableStateOf("") }; var debitAccount by remember { mutableStateOf<Long?>(null) }; var creditAccount by remember { mutableStateOf<Long?>(null) }; var amount by remember { mutableStateOf("") }; var debitExpanded by remember { mutableStateOf(false) }; var creditExpanded by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("سند حسابداری دستی") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(description, { description = it }, "شرح سند"); AccountSelect("حساب بدهکار", accounts, debitAccount, debitExpanded, { debitExpanded = it }) { debitAccount = it }; AccountSelect("حساب بستانکار", accounts, creditAccount, creditExpanded, { creditExpanded = it }) { creditAccount = it }; FormTextField(amount, { amount = it }, "مبلغ (تومان)"); Text("تاریخ سند: ${PersianDate.format(PersianDate.today())}", style = MaterialTheme.typography.labelMedium) } }, confirmButton = { TextButton(onClick = { if (debitAccount != null && creditAccount != null) { val raw = PersianNumbers.parseDisplayedAmount(amount) ?: 0; onSave(JournalInput(PersianDate.today(), description, listOf(JournalLineInput(debitAccount!!, debit = raw), JournalLineInput(creditAccount!!, credit = raw)))) } }) { Text("ثبت سند") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } })
}

@Composable
private fun AccountSelect(label: String, accounts: List<AccountEntity>, selected: Long?, expanded: Boolean, onExpanded: (Boolean) -> Unit, onSelect: (Long) -> Unit) { ExposedDropdownMenuBox(expanded, onExpanded) { OutlinedTextField(accounts.firstOrNull { it.id == selected }?.let { "${it.code} - ${it.name}" } ?: "انتخاب حساب", {}, readOnly = true, label = { Text(label) }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) }, modifier = Modifier.menuAnchor().fillMaxWidth()); ExposedDropdownMenu(expanded, { onExpanded(false) }) { accounts.forEach { account -> DropdownMenuItem(text = { Text("${account.code} - ${account.name}") }, onClick = { onSelect(account.id); onExpanded(false) }) } } } }

@Composable
private fun AccountEditor(onDismiss: () -> Unit, onSave: (AccountEntity) -> Unit) { var code by remember { mutableStateOf("") }; var name by remember { mutableStateOf("") }; var type by remember { mutableStateOf("ASSET") }; AlertDialog(onDismissRequest = onDismiss, title = { Text("حساب جدید") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(code, { code = it }, "کد حساب"); FormTextField(name, { name = it }, "نام حساب"); OutlinedTextField(accountTypeName(type), {}, readOnly = true, label = { Text("گروه حساب") }, modifier = Modifier.fillMaxWidth()); SingleChoiceSegmentedButtonRow { listOf("ASSET" to "دارایی", "LIABILITY" to "بدهی", "REVENUE" to "درآمد", "EXPENSE" to "هزینه").forEachIndexed { i, item -> SegmentedButton(type == item.first, { type = item.first }, SegmentedButtonDefaults.itemShape(i, 4)) { Text(item.second) } } } } }, confirmButton = { TextButton(onClick = { onSave(AccountEntity(code = code, name = name, type = type)) }) { Text("ذخیره") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } }) }

private fun accountTypeName(type: String) = when (type) { "ASSET" -> "دارایی"; "LIABILITY" -> "بدهی"; "EQUITY" -> "سرمایه"; "REVENUE" -> "درآمد"; else -> "هزینه" }
