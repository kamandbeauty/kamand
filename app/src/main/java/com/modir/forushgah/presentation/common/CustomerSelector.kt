package com.modir.forushgah.presentation.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Divider
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.domain.model.Customer

/**
 * Reusable customer picker for order screens (Phase 3), per spec §9: pick an
 * existing customer OR create one inline without navigating away. Stateless —
 * the host ViewModel owns the search flow; [onQuickCreate] wires the inline
 * creation to `CustomerRepository.quickCreate`.
 */
@Composable
fun CustomerSelectorDialog(
    customers: List<Customer>,
    query: String,
    onQueryChange: (String) -> Unit,
    onSelected: (Customer) -> Unit,
    onQuickCreate: ((name: String, mobile: String?) -> Unit)? = null,
    onDismiss: () -> Unit,
) {
    var quickName by remember { mutableStateOf("") }
    var quickMobile by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب مشتری") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                SearchField(
                    query = query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی مشتری",
                )
                LazyColumn(modifier = Modifier.heightIn(max = 280.dp)) {
                    items(customers, key = { it.id }) { customer ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(onClick = { onSelected(customer) })
                                .padding(horizontal = 8.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(customer.name, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                            customer.mobile?.let {
                                Text(
                                    PersianNumberFormatter.toPersianDigits(it),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                if (onQuickCreate != null) {
                    Divider()
                    Column(
                        modifier = Modifier.padding(top = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            "یا مشتری جدید بسازید",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = quickName,
                                onValueChange = { quickName = it },
                                label = { Text("نام") },
                                modifier = Modifier.weight(1f),
                                singleLine = true,
                            )
                            OutlinedTextField(
                                value = quickMobile,
                                onValueChange = { it.filter { c -> c.isDigit() || c == '+' } },
                                label = { Text("موبایل") },
                                modifier = Modifier.weight(1f),
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                            )
                        }
                        Button(
                            onClick = {
                                onQuickCreate(quickName.trim(), quickMobile.ifBlank { null })
                                quickName = ""
                                quickMobile = ""
                            },
                            enabled = quickName.isNotBlank(),
                        ) {
                            Text("ساخت و انتخاب")
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
