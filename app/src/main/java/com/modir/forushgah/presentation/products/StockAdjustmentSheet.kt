package com.modir.forushgah.presentation.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.input.KeyboardType
import com.modir.forushgah.core.common.PersianNumberFormatter

/**
 * Stock-adjustment dialog (spec §4): the user enters a NEW absolute stock
 * value and an optional reason; [ProductDetailViewModel.adjustStock] records
 * the resulting delta as an ADJUSTMENT_IN/ADJUSTMENT_OUT movement through the
 * only legitimate stock-mutation path (InventoryRepository).
 *
 * Pure UI — no repository access, so it's trivially previewable/testable.
 */
@Composable
fun StockAdjustmentSheet(
    currentStock: Int,
    onConfirm: (newStock: Int, reason: String?) -> Unit,
    onDismiss: () -> Unit,
) {
    var newStock by remember { mutableStateOf(currentStock.toString()) }
    var reason by remember { mutableStateOf("") }

    val parsedNewStock = newStock.toIntOrNull()
    val delta = parsedNewStock?.minus(currentStock)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("تنظیم موجودی") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "موجودی فعلی: ${PersianNumberFormatter.toPersianDigits(currentStock.toString())}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = newStock,
                    onValueChange = { it.filter { c -> c.isDigit() } },
                    label = { Text("موجودی جدید") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = reason,
                    onValueChange = { reason = it },
                    label = { Text("دلیل (اختیاری)") },
                    singleLine = true,
                )
                val deltaText = when {
                    delta == null -> "موجودی جدید را وارد کنید"
                    delta == 0 -> "بدون تغییر"
                    delta > 0 -> "افزایش ${PersianNumberFormatter.toPersianDigits(delta.toString())} واحد"
                    else -> "کاهش ${PersianNumberFormatter.toPersianDigits((-delta).toString())} واحد"
                }
                Text(
                    text = deltaText,
                    style = MaterialTheme.typography.bodyMedium,
                    color = when {
                        delta == null || delta == 0 -> MaterialTheme.colorScheme.onSurfaceVariant
                        delta > 0 -> MaterialTheme.colorScheme.primary
                        else -> MaterialTheme.colorScheme.error
                    },
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { parsedNewStock?.let { onConfirm(it, reason.ifBlank { null }) } },
                enabled = parsedNewStock != null,
            ) {
                Text("ذخیره")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("انصراف") }
        },
    )
}
