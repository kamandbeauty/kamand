@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package ir.javid.hesabyar.feature.products

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Category
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
import ir.javid.hesabyar.data.local.entity.InventoryTransactionEntity
import ir.javid.hesabyar.data.local.entity.ProductCategoryEntity
import ir.javid.hesabyar.data.local.entity.ProductEntity
import ir.javid.hesabyar.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProductsViewModel @Inject constructor(private val repository: ProductRepository) : ViewModel() {
    val products = repository.products
    val categories = repository.categories
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    fun save(product: ProductEntity, done: () -> Unit) = viewModelScope.launch {
        repository.save(product).fold(onSuccess = { done() }, onFailure = { _message.value = it.message ?: "ذخیره کالا انجام نشد" })
    }
    fun archive(id: Long) = viewModelScope.launch { repository.archive(id).onFailure { _message.value = it.message } }
    fun inventory(productId: Long) = repository.inventory(productId)
    fun saveCategory(name: String, done: () -> Unit) = viewModelScope.launch { repository.saveCategory(ProductCategoryEntity(name = name)).fold({ done() }, { _message.value = it.message }) }
    fun deleteCategory(category: ProductCategoryEntity) = viewModelScope.launch { repository.deleteCategory(category).onFailure { _message.value = it.message } }
    fun dismissMessage() { _message.value = null }
}

@Composable
fun ProductsScreen(viewModel: ProductsViewModel = hiltViewModel()) {
    val products by viewModel.products.collectAsStateWithLifecycle(initialValue = emptyList())
    val categories by viewModel.categories.collectAsStateWithLifecycle(initialValue = emptyList())
    val message by viewModel.message.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<ProductEntity?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var showCategories by remember { mutableStateOf(false) }
    var historyProduct by remember { mutableStateOf<ProductEntity?>(null) }
    AppScreen(
        title = "کالاها",
        actions = { IconButton(onClick = { showCategories = true }) { Icon(Icons.Outlined.Category, "دسته‌بندی‌ها") } },
        floatingActionButton = { ExtendedFloatingActionButton(onClick = { editing = null; showEditor = true }, icon = { Icon(Icons.Outlined.Add, null) }, text = { Text("کالای جدید") }) }
    ) {
        if (products.isEmpty()) EmptyState("هنوز کالایی ثبت نشده", "برای صدور فاکتور، اولین کالا یا خدمت خود را ثبت کنید.")
        else LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 90.dp)) {
            items(products, key = { it.id }) { product ->
                SectionCard(onClick = { editing = product; showEditor = true }) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column(Modifier.weight(1f)) {
                            Text(product.name, fontWeight = FontWeight.Bold)
                            Text(if (product.trackInventory) "${PersianNumbers.quantity(product.stock)} ${product.unit} موجودی" else "خدمت (بدون موجودی)", color = if (product.trackInventory && product.stock <= product.minimumStock) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = androidx.compose.ui.Alignment.End) {
                            MoneyText(product.salePrice, style = MaterialTheme.typography.titleSmall)
                            Text("قیمت فروش", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            TextButton(onClick = { historyProduct = product }) { Text("گردش") }
                        }
                    }
                }
            }
        }
    }
    if (showEditor) ProductEditor(editing, categories, onDismiss = { showEditor = false }, onSave = { product -> viewModel.save(product) { showEditor = false } }, onArchive = editing?.let { { viewModel.archive(it.id); showEditor = false } })
    if (showCategories) CategoryDialog(categories, onDismiss = { showCategories = false }, onSave = { viewModel.saveCategory(it) {} }, onDelete = viewModel::deleteCategory)
    historyProduct?.let { InventoryHistoryDialog(it, viewModel.inventory(it.id), onDismiss = { historyProduct = null }) }
    message?.let { Snackbar(modifier = Modifier.padding(16.dp), action = { TextButton(onClick = viewModel::dismissMessage) { Text("بستن") } }) { Text(it) } }
}

@Composable
private fun ProductEditor(product: ProductEntity?, categories: List<ProductCategoryEntity>, onDismiss: () -> Unit, onSave: (ProductEntity) -> Unit, onArchive: (() -> Unit)?) {
    var name by remember(product) { mutableStateOf(product?.name.orEmpty()) }
    var purchase by remember(product) { mutableStateOf(product?.let { PersianNumbers.amountWithoutCurrency(it.purchasePrice) }.orEmpty()) }
    var sale by remember(product) { mutableStateOf(product?.let { PersianNumbers.amountWithoutCurrency(it.salePrice) }.orEmpty()) }
    var stock by remember(product) { mutableStateOf(product?.stock?.toString().orEmpty()) }
    var minStock by remember(product) { mutableStateOf(product?.minimumStock?.toString().orEmpty()) }
    var unit by remember(product) { mutableStateOf(product?.unit ?: "عدد") }
    var sku by remember(product) { mutableStateOf(product?.sku.orEmpty()) }
    var categoryId by remember(product) { mutableStateOf(product?.categoryId) }
    var categoryExpanded by remember { mutableStateOf(false) }
    var trackInventory by remember(product) { mutableStateOf(product?.trackInventory ?: true) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (product == null) "ثبت کالا" else "ویرایش کالا") },
        text = {
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                FormTextField(name, { name = it }, "نام کالا یا خدمت")
                FormTextField(sku, { sku = it }, "کد کالا (اختیاری)")
                ExposedDropdownMenuBox(expanded = categoryExpanded, onExpandedChange = { categoryExpanded = !categoryExpanded }) {
                    OutlinedTextField(value = categories.firstOrNull { it.id == categoryId }?.name ?: "بدون دسته‌بندی", onValueChange = {}, readOnly = true, label = { Text("دسته‌بندی") }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(categoryExpanded) }, modifier = Modifier.menuAnchor().fillMaxWidth())
                    ExposedDropdownMenu(expanded = categoryExpanded, onDismissRequest = { categoryExpanded = false }) {
                        DropdownMenuItem(text = { Text("بدون دسته‌بندی") }, onClick = { categoryId = null; categoryExpanded = false })
                        categories.forEach { category -> DropdownMenuItem(text = { Text(category.name) }, onClick = { categoryId = category.id; categoryExpanded = false }) }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FormTextField(purchase, { purchase = it }, "خرید (تومان)", Modifier.weight(1f))
                    FormTextField(sale, { sale = it }, "فروش (تومان)", Modifier.weight(1f))
                }
                Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    Switch(checked = trackInventory, onCheckedChange = { trackInventory = it })
                    Spacer(Modifier.width(8.dp)); Text("مدیریت موجودی برای این کالا")
                }
                if (trackInventory) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FormTextField(stock, { stock = it }, if (product == null) "موجودی اولیه" else "موجودی فعلی", Modifier.weight(1f))
                    FormTextField(minStock, { minStock = it }, "حداقل موجودی", Modifier.weight(1f))
                }
                FormTextField(unit, { unit = it }, "واحد (مثلاً عدد، کیلو)")
            }
        },
        confirmButton = { TextButton(onClick = {
            onSave((product ?: ProductEntity(name = "")).copy(name = name, sku = sku.ifBlank { null }, categoryId = categoryId, purchasePrice = PersianNumbers.parseDisplayedAmount(purchase) ?: 0, salePrice = PersianNumbers.parseDisplayedAmount(sale) ?: 0, stock = stock.toDoubleOrNull() ?: 0.0, minimumStock = minStock.toDoubleOrNull() ?: 0.0, unit = unit.ifBlank { "عدد" }, trackInventory = trackInventory))
        }) { Text("ذخیره") } },
        dismissButton = { Row { onArchive?.let { TextButton(onClick = it) { Text("حذف", color = MaterialTheme.colorScheme.error) } }; TextButton(onClick = onDismiss) { Text("انصراف") } } }
    )
}

@Composable
private fun CategoryDialog(categories: List<ProductCategoryEntity>, onDismiss: () -> Unit, onSave: (String) -> Unit, onDelete: (ProductCategoryEntity) -> Unit) {
    var value by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("دسته‌بندی کالا") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FormTextField(value, { value = it }, "نام دسته‌بندی جدید"); categories.forEach { category -> Row(Modifier.fillMaxWidth(), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) { Text(category.name, Modifier.weight(1f)); IconButton(onClick = { onDelete(category) }) { Icon(Icons.Outlined.DeleteOutline, "حذف") } } } } }, confirmButton = { TextButton(onClick = { if (value.isNotBlank()) { onSave(value); value = "" } }) { Text("افزودن") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("بستن") } })
}
