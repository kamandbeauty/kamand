package ir.javid.hesabyar.feature.parties

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.PersianNumbers
import ir.javid.hesabyar.data.local.entity.PartyEntity
import ir.javid.hesabyar.data.local.entity.PartyTransactionEntity
import kotlinx.coroutines.flow.Flow

@Composable
fun PartyHistoryDialog(party: PartyEntity, transactions: Flow<List<PartyTransactionEntity>>, onDismiss: () -> Unit) {
    val rows by transactions.collectAsStateWithLifecycle(initialValue = emptyList())
    AlertDialog(onDismissRequest = onDismiss, title = { Text("گردش حساب: ${party.name}") }, text = {
        if (rows.isEmpty()) Text("گردشی برای این شخص ثبت نشده است.")
        else LazyColumn(Modifier.heightIn(max = 360.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) { items(rows, key = { it.id }) { row -> ListItem(headlineContent = { Text(partyTransactionName(row.type)) }, supportingContent = { Text("${PersianDate.format(row.dateEpochDay)} • ${row.note}") }, trailingContent = { Text("${if (row.amount >= 0) "+" else ""}${PersianNumbers.amount(row.amount)}") }); HorizontalDivider() } }
    }, confirmButton = { TextButton(onClick = onDismiss) { Text("بستن") } })
}

private fun partyTransactionName(type: String) = when (type) { "SALE" -> "فاکتور فروش"; "PURCHASE" -> "فاکتور خرید"; "RECEIPT" -> "دریافت وجه"; "PAYMENT" -> "پرداخت وجه"; "OPENING_BALANCE" -> "مانده اول دوره"; else -> "اصلاح / ابطال" }
