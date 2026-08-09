package com.forushyar.app.ui.orders

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.AddShoppingCart
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.forushyar.app.R
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.local.entity.Product
import com.forushyar.app.util.FormatUtils
import kotlinx.coroutines.flow.collectLatest

@Composable
fun OrderFormScreen(
    onBack: () -> Unit,
    onSaved: (Long) -> Unit,
    viewModel: OrderFormViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val saveError = stringResource(R.string.order_save_error)

    LaunchedEffect(viewModel) {
        viewModel.events.collectLatest { event ->
            when (event) {
                is OrderFormEvent.Saved -> onSaved(event.orderId)
                OrderFormEvent.SaveFailed -> snackbar.showSnackbar(saveError)
            }
        }
    }

    OrderFormContent(
        state = state,
        snackbar = snackbar,
        onBack = onBack,
        onSelectCustomer = viewModel::selectCustomer,
        onAddProduct = viewModel::addProduct,
        onRemoveProduct = viewModel::removeProduct,
        onQuantityChange = viewModel::changeQuantity,
        onBuyPriceChange = viewModel::changeBuyPrice,
        onSellPriceChange = viewModel::changeSellPrice,
        onNoteChange = viewModel::changeNote,
        onSave = viewModel::save
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OrderFormContent(
    state: OrderFormState,
    snackbar: SnackbarHostState,
    onBack: () -> Unit,
    onSelectCustomer: (Long) -> Unit,
    onAddProduct: (Product) -> Unit,
    onRemoveProduct: (Long) -> Unit,
    onQuantityChange: (Long, Int) -> Unit,
    onBuyPriceChange: (Long, String) -> Unit,
    onSellPriceChange: (Long, String) -> Unit,
    onNoteChange: (String) -> Unit,
    onSave: () -> Unit
) {
    var showCustomers by remember { mutableStateOf(false) }
    var showProducts by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.add_order)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier.padding(paddingValues).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text(
                    stringResource(R.string.order_customer),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                OutlinedButton(
                    onClick = { showCustomers = true },
                    enabled = state.customers.isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                ) {
                    Text(
                        state.selectedCustomer?.name
                            ?: stringResource(
                                if (state.customers.isEmpty()) R.string.no_customers_for_order
                                else R.string.select_customer
                            )
                    )
                }
                if (state.error == OrderFormError.CUSTOMER_REQUIRED) {
                    FormError(stringResource(R.string.select_customer_error))
                }
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        stringResource(R.string.order_items),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    OutlinedButton(
                        onClick = { showProducts = true },
                        enabled = state.products.isNotEmpty()
                    ) {
                        Icon(Icons.Outlined.AddShoppingCart, contentDescription = null)
                        Text(stringResource(R.string.add_order_item), modifier = Modifier.padding(start = 6.dp))
                    }
                }
                if (state.products.isEmpty()) {
                    Text(
                        stringResource(R.string.no_products_for_order),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                if (state.error == OrderFormError.ITEMS_REQUIRED) {
                    FormError(stringResource(R.string.add_item_error))
                }
                if (state.error == OrderFormError.INVALID_ITEM) {
                    FormError(stringResource(R.string.invalid_order_item_error))
                }
            }

            items(state.items, key = { it.productId }) { item ->
                DraftItemCard(
                    item = item,
                    onRemove = { onRemoveProduct(item.productId) },
                    onQuantityChange = { onQuantityChange(item.productId, it) },
                    onBuyPriceChange = { onBuyPriceChange(item.productId, it) },
                    onSellPriceChange = { onSellPriceChange(item.productId, it) }
                )
            }

            item {
                OutlinedTextField(
                    value = state.note,
                    onValueChange = onNoteChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.order_note_optional)) },
                    minLines = 2,
                    maxLines = 4
                )
            }
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.order_total), fontWeight = FontWeight.Bold)
                    Text(FormatUtils.formatPrice(state.total), fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onSave,
                    enabled = !state.isSaving,
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
                ) {
                    if (state.isSaving) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp).padding(end = 4.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                    Text(stringResource(R.string.save_order))
                }
                Spacer(Modifier.height(16.dp))
            }
        }
    }

    if (showCustomers) {
        CustomerPickerDialog(
            customers = state.customers,
            onDismiss = { showCustomers = false },
            onSelect = {
                onSelectCustomer(it.id)
                showCustomers = false
            }
        )
    }
    if (showProducts) {
        ProductPickerDialog(
            products = state.products,
            onDismiss = { showProducts = false },
            onSelect = {
                onAddProduct(it)
                showProducts = false
            }
        )
    }
}

@Composable
private fun DraftItemCard(
    item: OrderDraftItem,
    onRemove: () -> Unit,
    onQuantityChange: (Int) -> Unit,
    onBuyPriceChange: (String) -> Unit,
    onSellPriceChange: (String) -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(item.productName, fontWeight = FontWeight.SemiBold)
                    Text(
                        stringResource(R.string.available_stock, FormatUtils.formatNumber(item.availableStock.toLong())),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onRemove) {
                    Icon(
                        Icons.Outlined.Delete,
                        contentDescription = stringResource(R.string.remove_order_item),
                        tint = MaterialTheme.colorScheme.error
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.quantity), modifier = Modifier.weight(1f))
                IconButton(onClick = { onQuantityChange(-1) }) {
                    Icon(Icons.Default.Remove, contentDescription = stringResource(R.string.decrease_quantity))
                }
                Text(FormatUtils.formatNumber(item.quantity.toLong()), fontWeight = FontWeight.Bold)
                IconButton(onClick = { onQuantityChange(1) }) {
                    Icon(Icons.Default.Add, contentDescription = stringResource(R.string.increase_quantity))
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PriceField(
                    value = item.buyPrice,
                    onValueChange = onBuyPriceChange,
                    label = stringResource(R.string.product_buy_price),
                    modifier = Modifier.weight(1f)
                )
                PriceField(
                    value = item.sellPrice,
                    onValueChange = onSellPriceChange,
                    label = stringResource(R.string.product_sell_price),
                    modifier = Modifier.weight(1f)
                )
            }
            Text(
                stringResource(R.string.item_total, FormatUtils.formatPrice(item.total)),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun PriceField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
    )
}

@Composable
private fun CustomerPickerDialog(
    customers: List<Customer>,
    onDismiss: () -> Unit,
    onSelect: (Customer) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.select_customer)) },
        text = {
            LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 360.dp)) {
                items(customers, key = { it.id }) { customer ->
                    Text(
                        customer.name,
                        modifier = Modifier.fillMaxWidth().clickable { onSelect(customer) }.padding(14.dp)
                    )
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

@Composable
private fun ProductPickerDialog(
    products: List<Product>,
    onDismiss: () -> Unit,
    onSelect: (Product) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.select_product)) },
        text = {
            LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 360.dp)) {
                items(products, key = { it.id }) { product ->
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onSelect(product) }.padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(product.name)
                        Text(
                            FormatUtils.formatPrice(product.sellPrice),
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

@Composable
private fun FormError(text: String) {
    Text(
        text = text,
        color = MaterialTheme.colorScheme.error,
        style = MaterialTheme.typography.bodySmall,
        modifier = Modifier.padding(top = 4.dp)
    )
}
