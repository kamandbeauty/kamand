@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.parties

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
import ir.javid.hesabyar.core.ui.*
import ir.javid.hesabyar.data.local.entity.PartyEntity
import ir.javid.hesabyar.data.local.entity.PartyTransactionEntity
import ir.javid.hesabyar.domain.repository.PartyRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PartiesViewModel @Inject constructor(private val repository: PartyRepository) : ViewModel() {
    val parties = repository.parties
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    fun save(party: PartyEntity, done: () -> Unit) = viewModelScope.launch { repository.save(party).fold({ done() }, { _message.value = it.message ?: "ذخیره شخص انجام نشد" }) }
    fun archive(id: Long) = viewModelScope.launch { repository.archive(id).onFailure { _message.value = it.message } }
    fun transactions(partyId: Long) = repository.transactions(partyId)
    fun dismissMessage() { _message.value = null }
}

@Composable
fun PartiesScreen(viewModel: PartiesViewModel = hiltViewModel()) {
    val parties by viewModel.parties.collectAsStateWithLifecycle(initialValue = emptyList())
    val message by viewModel.message.collectAsStateWithLifecycle()
    var editor by remember { mutableStateOf<PartyEntity?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var historyParty by remember { mutableStateOf<PartyEntity?>(null) }
    AppScreen("اشخاص", floatingActionButton = { ExtendedFloatingActionButton(onClick = { editor = null; showEditor = true }, icon = { Icon(Icons.Outlined.Add, null) }, text = { Text("شخص جدید") }) }) {
        if (parties.isEmpty()) EmptyState("دفتر اشخاص خالی است", "مشتریان، فروشندگان و سایر طرف‌حساب‌ها را اینجا ثبت کنید.")
        else LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 90.dp)) {
            items(parties, key = { it.id }) { party ->
                SectionCard(onClick = { editor = party; showEditor = true }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(party.name, fontWeight = FontWeight.Bold)
                            Text("${partyTypeName(party.type)}${party.phone.takeIf { it.isNotBlank() }?.let { " • $it" }.orEmpty()}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(if (party.balance > 0) "بدهکار" else if (party.balance < 0) "بستانکار" else "تسویه", style = MaterialTheme.typography.labelMedium, color = if (party.balance == 0L) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                            MoneyText(kotlin.math.abs(party.balance), style = MaterialTheme.typography.titleSmall)
                            TextButton(onClick = { historyParty = party }) { Text("گردش") }
                        }
                    }
                }
            }
        }
    }
    if (showEditor) PartyEditor(editor, { showEditor = false }, { viewModel.save(it) { showEditor = false } }, editor?.let { { viewModel.archive(it.id); showEditor = false } })
    historyParty?.let { PartyHistoryDialog(it, viewModel.transactions(it.id), onDismiss = { historyParty = null }) }
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun PartyEditor(party: PartyEntity?, onDismiss: () -> Unit, onSave: (PartyEntity) -> Unit, onArchive: (() -> Unit)?) {
    var name by remember(party) { mutableStateOf(party?.name.orEmpty()) }
    var phone by remember(party) { mutableStateOf(party?.phone.orEmpty()) }
    var address by remember(party) { mutableStateOf(party?.address.orEmpty()) }
    var notes by remember(party) { mutableStateOf(party?.notes.orEmpty()) }
    var balance by remember(party) { mutableStateOf(party?.let { PersianNumbers.amountWithoutCurrency(kotlin.math.abs(it.balance)) }.orEmpty()) }
    var balanceSign by remember(party) { mutableIntStateOf(if ((party?.balance ?: 0L) < 0L) -1 else 1) }
    var type by remember(party) { mutableStateOf(party?.type ?: "CUSTOMER") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (party == null) "ثبت شخص" else "ویرایش شخص") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            FormTextField(name, { name = it }, "نام و نام خانوادگی / نام کسب‌وکار")
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                listOf("CUSTOMER" to "مشتری", "SUPPLIER" to "فروشنده", "OTHER" to "سایر").forEachIndexed { index, (value, label) ->
                    SegmentedButton(selected = type == value, onClick = { type = value; if (party == null && value == "SUPPLIER") balanceSign = -1 }, shape = SegmentedButtonDefaults.itemShape(index, 3)) { Text(label) }
                }
            }
            FormTextField(phone, { phone = it }, "شماره تماس")
            FormTextField(address, { address = it }, "آدرس", singleLine = false)
            FormTextField(balance, { balance = it }, "مانده اول دوره (تومان)")
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                SegmentedButton(selected = balanceSign > 0, onClick = { balanceSign = 1 }, shape = SegmentedButtonDefaults.itemShape(0, 2)) { Text("بدهکار به ما") }
                SegmentedButton(selected = balanceSign < 0, onClick = { balanceSign = -1 }, shape = SegmentedButtonDefaults.itemShape(1, 2)) { Text("بستانکار از ما") }
            }
            FormTextField(notes, { notes = it }, "توضیحات", singleLine = false)
        }
    }, confirmButton = { TextButton(onClick = {
        val rawBalance = PersianNumbers.parseDisplayedAmount(balance) ?: 0
        val actualBalance = rawBalance * balanceSign
        onSave((party ?: PartyEntity(name = "", type = type)).copy(name = name, type = type, phone = phone, address = address, notes = notes, balance = actualBalance))
    }) { Text("ذخیره") } }, dismissButton = { Row { onArchive?.let { TextButton(onClick = it) { Text("حذف", color = MaterialTheme.colorScheme.error) } }; TextButton(onClick = onDismiss) { Text("انصراف") } } })
}

private fun partyTypeName(type: String) = when (type) { "CUSTOMER" -> "مشتری"; "SUPPLIER" -> "فروشنده"; else -> "سایر" }
