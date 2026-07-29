package ir.javid.hesabyar.feature.products

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
import ir.javid.hesabyar.data.local.entity.InventoryTransactionEntity
import ir.javid.hesabyar.data.local.entity.ProductEntity
import kotlinx.coroutines.flow.Flow

@Composable
fun InventoryHistoryDialog(product: ProductEntity, transactions: Flow<List<InventoryTransactionEntity>>, onDismiss: () -> Unit) {
    val rows by transactions.collectAsStateWithLifecycle(initialValue = emptyList())
    AlertDialog(onDismissRequest = onDismiss, title = { Text("گردش کالا: ${product.name}") }, text = {
        if (rows.isEmpty()) Text("گردشی برای این کالا ثبت نشده است.")
        else LazyColumn(Modifier.heightIn(max = 360.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(rows, key = { it.id }) { row ->
                ListItem(headlineContent = { Text(inventoryType(row.type)) }, supportingContent = { Text("${PersianDate.format(row.dateEpochDay)} • ${row.note}") }, trailingContent = { Text("${if (row.quantity > 0) "+" else ""}${PersianNumbers.quantity(row.quantity)}") })
                HorizontalDivider()
            }
        }
    }, confirmButton = { TextButton(onClick = onDismiss) { Text("بستن") } })
}

private fun inventoryType(type: String) = when (type) { "SALE" -> "فروش"; "PURCHASE" -> "خرید"; "SALE_RETURN" -> "برگشت از فروش"; "PURCHASE_RETURN" -> "برگشت از خرید"; else -> "اصلاح موجودی" }
