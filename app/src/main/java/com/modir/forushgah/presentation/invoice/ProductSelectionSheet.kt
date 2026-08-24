package com.modir.forushgah.presentation.invoice

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.AddBox
import androidx.compose.material3.Divider
import androidx.compose.material3.ElevatedButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.modir.forushgah.core.common.InvoiceFormatting
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.domain.model.Product

private val SheetOrange = Color(0xFFF97316)
private val SheetOrangeContainer = Color(0xFFFFEDD5)
private val SheetSlate500 = Color(0xFF64748B)
private val SheetSlate800 = Color(0xFF1E293B)
private val SheetGray = Color(0xFFE2E8F0)

/**
 * Rubi-style product selection popup (spec §4): search, browse the real
 * database, pick a product, choose the quantity, add to the invoice — without
 * losing any invoice state. «درج محصول جدید» opens the Rubi product form
 * (spec §5); «قلم دستی» keeps Rubi's free manual line.
 */
@Composable
fun ProductSelectionSheet(
    products: List<Product>,
    query: String,
    isPurchase: Boolean,
    onQueryChange: (String) -> Unit,
    onProductSelected: (productId: Long, quantity: Int) -> Unit,
    onFreeItemAdded: () -> Unit,
    onAddProductClick: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        sheetGesturesEnabled = false, // explicit buttons only — Rubi sheets are button-driven
    )
    var selectedProductId by remember { mutableStateOf<Long?>(null) }
    var quantity by remember { mutableStateOf(1) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp),
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            // drag handle (Rubi)
            Box(
                modifier = Modifier
                    .size(width = 42.dp, height = 4.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(SheetGray)
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 14.dp),
            )
            Text(
                "انتخاب محصول",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.W900,
                color = SheetSlate800,
                modifier = Modifier.padding(bottom = 12.dp),
            )
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                label = { Text("جستجوی محصول یا کد") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(onClick = onAddProductClick, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Outlined.AddBox, contentDescription = null, tint = SheetOrange)
                Spacer(modifier = Modifier.width(6.dp))
                Text("درج محصول جدید", color = SheetOrange, fontWeight = FontWeight.W800)
            }
            TextButton(onClick = onFreeItemAdded, modifier = Modifier.fillMaxWidth()) {
                Text("قلم دستی (بدون محصول)", color = SheetSlate500, fontWeight = FontWeight.W700)
            }
            Divider()
            Spacer(modifier = Modifier.height(8.dp))
            if (products.isEmpty()) {
                Text(
                    if (query.isBlank()) "هنوز محصولی ثبت نشده است" else "محصولی با این جستجو پیدا نشد",
                    style = MaterialTheme.typography.bodyMedium,
                    color = SheetSlate500,
                    fontWeight = FontWeight.W700,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 24.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            } else {
                LazyColumn(
                    modifier = Modifier.height(320.dp),
                    contentPadding = PaddingValues(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(products, key = { it.id }) { product ->
                        val selected = selectedProductId == product.id
                        ProductSelectionRow(
                            product = product,
                            isPurchase = isPurchase,
                            selected = selected,
                            quantity = if (selected) quantity else 1,
                            onToggle = {
                                if (selected) {
                                    selectedProductId = null
                                } else {
                                    selectedProductId = product.id
                                    quantity = 1
                                }
                            },
                            onQuantityMinus = {
                                if (selected) quantity = (quantity - 1).coerceAtLeast(1)
                            },
                            onQuantityPlus = {
                                if (selected) quantity = (quantity + 1).coerceAtMost(if (isPurchase) 999999 else product.stockQuantity.coerceAtLeast(1))
                            },
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            ElevatedButton(
                onClick = {
                    val id = selectedProductId
                    if (id != null) onProductSelected(id, quantity)
                },
                enabled = selectedProductId != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                colors = androidx.compose.material3.ButtonDefaults.elevatedButtonColors(containerColor = SheetOrange),
            ) {
                Icon(Icons.Filled.Check, contentDescription = null, tint = Color.White)
                Spacer(modifier = Modifier.width(8.dp))
                Text("افزودن به فاکتور", color = Color.White, fontWeight = FontWeight.W900)
            }
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                Text("انصراف", color = SheetSlate500)
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/** Rubi product card, selectable: code box + name + «موجودی / قیمت فروش» + quantity stepper. */
@Composable
private fun ProductSelectionRow(
    product: Product,
    isPurchase: Boolean,
    selected: Boolean,
    quantity: Int,
    onToggle: () -> Unit,
    onQuantityMinus: () -> Unit,
    onQuantityPlus: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = androidx.compose.foundation.BorderStroke(1.dp, if (selected) SheetOrange else SheetGray),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = SheetOrangeContainer,
                    modifier = Modifier.padding(end = 10.dp),
                ) {
                    Text(
                        PersianNumberFormatter.toPersianDigits(product.sku),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = SheetOrange,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                    )
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        product.name,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.W900,
                        color = SheetSlate800,
                        maxLines = 1,
                    )
                    val price = if (isPurchase) product.purchasePrice else product.sellingPrice
                    Text(
                        "موجودی: ${PersianNumberFormatter.toPersianDigits(product.stockQuantity.toString())} ${product.unit}  •  " +
                            (if (isPurchase) "قیمت خرید: " else "قیمت فروش: ") + InvoiceFormatting.formatCurrency(price),
                        style = MaterialTheme.typography.bodySmall,
                        color = SheetSlate500,
                        fontSize = 11.sp,
                    )
                }
                Surface(
                    onClick = onToggle,
                    shape = CircleShape,
                    color = if (selected) SheetOrange else Color(0xFFF8FAFC),
                    modifier = Modifier.size(28.dp),
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        if (selected) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
            if (selected) {
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text("تعداد", style = MaterialTheme.typography.bodyMedium, color = SheetSlate500, modifier = Modifier.weight(1f))
                    Surface(onClick = onQuantityMinus, shape = CircleShape, color = SheetOrangeContainer) {
                        Icon(
                            Icons.Filled.Remove,
                            contentDescription = "کاهش",
                            tint = SheetOrange,
                            modifier = Modifier.size(30.dp).padding(5.dp),
                        )
                    }
                    Text(
                        PersianNumberFormatter.toPersianDigits(quantity.toString()),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.W800,
                        modifier = Modifier.padding(horizontal = 14.dp),
                    )
                    Surface(onClick = onQuantityPlus, shape = CircleShape, color = SheetOrangeContainer) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = "افزایش",
                            tint = SheetOrange,
                            modifier = Modifier.size(30.dp).padding(5.dp),
                        )
                    }
                }
            }
        }
    }
}

/**
 * Rubi product form bottom sheet (spec §5) — «درج محصول جدید» — field order
 * and labels exactly as the reference: name, unit+code, sell+buy price,
 * stock, notes. Saving makes the product immediately available in the
 * selector (the flow re-observes the database).
 */
@Composable
fun ProductFormSheet(
    onCreated: (name: String, code: String, unit: String, sellPrice: String, buyPrice: String, stock: String, notes: String) -> String?,
    onClose: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var unit by remember { mutableStateOf("عدد") }
    var sellPrice by remember { mutableStateOf("") }
    var buyPrice by remember { mutableStateOf("") }
    var stock by remember { mutableStateOf("0") }
    var notes by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        dragHandle = null,
        shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(width = 42.dp, height = 4.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(SheetGray)
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 4.dp),
            )
            Text(
                "درج محصول جدید",
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.W900,
                color = SheetSlate800,
            )
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("نام محصول یا خدمت *") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                isError = error != null,
            )
            if (error != null) {
                Text(error!!, color = Color(0xFFE11D48), style = MaterialTheme.typography.bodySmall)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = unit,
                    onValueChange = { unit = it },
                    label = { Text("واحد") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it },
                    label = { Text("کد محصول") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = sellPrice,
                    onValueChange = { sellPrice = it.filter { c -> c.isDigit() } },
                    label = { Text("قیمت فروش") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                OutlinedTextField(
                    value = buyPrice,
                    onValueChange = { buyPrice = it.filter { c -> c.isDigit() } },
                    label = { Text("قیمت خرید") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
            }
            OutlinedTextField(
                value = stock,
                onValueChange = { stock = it.filter { c -> c.isDigit() } },
                label = { Text("موجودی") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("توضیحات") },
                maxLines = 2,
                modifier = Modifier.fillMaxWidth(),
            )
            ElevatedButton(
                onClick = {
                    val err = onCreated(name, code, unit, sellPrice, buyPrice, stock, notes)
                    if (err == null) onClose() else error = err
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                colors = androidx.compose.material3.ButtonDefaults.elevatedButtonColors(containerColor = SheetOrange),
            ) {
                Icon(Icons.Filled.Add, contentDescription = null, tint = Color.White)
                Spacer(modifier = Modifier.width(8.dp))
                Text("درج محصول", color = Color.White, fontWeight = FontWeight.W800)
            }
        }
    }
}
