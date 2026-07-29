package ir.javid.hesabyar.feature.accounting

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
import ir.javid.hesabyar.data.local.dao.JournalLineRow
import ir.javid.hesabyar.data.local.entity.AccountEntity
import kotlinx.coroutines.flow.Flow

@Composable
fun LedgerDialog(account: AccountEntity, rows: Flow<List<JournalLineRow>>, onDismiss: () -> Unit) {
    val lines by rows.collectAsStateWithLifecycle(initialValue = emptyList())
    AlertDialog(onDismissRequest = onDismiss, title = { Text("دفتر کل: ${account.name}") }, text = {
        if (lines.isEmpty()) Text("گردشی در ماه جاری وجود ندارد.")
        else LazyColumn(Modifier.heightIn(max = 370.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) { items(lines) { row -> ListItem(headlineContent = { Text(row.entryNumber) }, supportingContent = { Text("${PersianDate.format(row.dateEpochDay)} • ${row.description}") }, trailingContent = { Column { Text("بد: ${PersianNumbers.amount(row.debit)}", style = MaterialTheme.typography.labelSmall); Text("بس: ${PersianNumbers.amount(row.credit)}", style = MaterialTheme.typography.labelSmall) } }); HorizontalDivider() } }
    }, confirmButton = { TextButton(onClick = onDismiss) { Text("بستن") } })
}
