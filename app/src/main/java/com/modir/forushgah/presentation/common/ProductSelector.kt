package com.modir.forushgah.presentation.common

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Divider
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.modir.forushgah.domain.model.Product

/**
 * Reusable product picker for order screens (Phase 3). Stateless on purpose:
 * the host ViewModel drives the search results via
 * `ProductRepository.observeSearch`/`observeActiveProducts` and passes them in,
 * so one implementation serves the order flow, stock screens, etc. — same
 * pattern as [ProductRow].
 */
@Composable
fun ProductSelectorDialog(
    products: List<Product>,
    query: String,
    onQueryChange: (String) -> Unit,
    onSelected: (Product) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب محصول") },
        text = {
            Column {
                SearchField(
                    query = query,
                    onQueryChange = onQueryChange,
                    placeholder = "جستجوی محصول یا بارکد",
                )
                LazyColumn(modifier = Modifier.heightIn(max = 360.dp)) {
                    items(products, key = { it.id }) { product ->
                        ProductRow(product = product, onClick = { onSelected(product) })
                        Divider()
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
