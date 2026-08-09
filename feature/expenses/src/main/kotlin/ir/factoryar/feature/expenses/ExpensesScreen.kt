package ir.factoryar.feature.expenses

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.factoryar.core.common.jalali.JalaliConverter
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.common.util.PersianFormatter.toPersianDigits
import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ReportRange
import ir.factoryar.core.ui.components.EmptyState
import ir.factoryar.core.ui.components.FyTopBar
import ir.factoryar.core.ui.components.JalaliDatePickerDialog
import ir.factoryar.core.ui.components.MoneyText
import ir.factoryar.core.ui.components.SectionHeader

@Composable
fun ExpensesScreen(
    onBack: () -> Unit,
    viewModel: ExpensesViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<Expense?>(null) }
    var showEditor by remember { mutableStateOf(false) }

    Scaffold(
        topBar = { FyTopBar(title = "هزینه‌های کسب‌وکار", onBack = onBack) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { editing = null; showEditor = true },
                icon = { Icon(Icons.Filled.Add, null) },
                text = { Text("ثبت هزینه") },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 90.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(ReportRange.entries.filter { it != ReportRange.CUSTOM }) { r ->
                        FilterChip(
                            selected = state.range == r,
                            onClick = { viewModel.setRange(r) },
                            label = { Text(r.faName, style = MaterialTheme.typography.labelMedium) },
                        )
                    }
                }
            }

            // خلاصه سود و زیان
            state.profit?.let { report ->
                item { ProfitSummaryCard(report) }
            }

            if (state.categories.isNotEmpty()) {
                item {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        item {
                            FilterChip(
                                selected = state.categoryId == null,
                                onClick = { viewModel.setCategory(null) },
                                label = { Text("همه", style = MaterialTheme.typography.labelSmall) },
                            )
                        }
                        items(state.categories) { c ->
                            FilterChip(
                                selected = state.categoryId == c.id,
                                onClick = { viewModel.setCategory(if (state.categoryId == c.id) null else c.id) },
                                label = { Text(c.name, style = MaterialTheme.typography.labelSmall) },
                            )
                        }
                    }
                }
            }

            item {
                SectionHeader(title = "فهرست هزینه‌ها") {
                    MoneyText(state.total, style = MaterialTheme.typography.labelLarge)
                }
            }

            if (state.expenses.isEmpty() && !state.isLoading) {
                item {
                    EmptyState(
                        icon = Icons.Filled.ReceiptLong,
                        title = "هزینه‌ای در این بازه ثبت نشده",
                        description = "با ثبت هزینه‌های اجاره، حقوق، قبوض و… سود خالص واقعی کسب‌وکارتان محاسبه می‌شود.",
                        actionLabel = "ثبت اولین هزینه",
                        onAction = { editing = null; showEditor = true },
                        modifier = Modifier.height(300.dp),
                    )
                }
            }

            items(state.expenses, key = { it.expense.id }) { row ->
                ExpenseRow(
                    row = row,
                    onClick = { editing = row.expense; showEditor = true },
                    onDelete = { viewModel.deleteExpense(row.expense.id) },
                )
            }
        }
    }

    if (showEditor) {
        ExpenseEditorDialog(
            initial = editing,
            categories = state.categories,
            onDismiss = { showEditor = false },
            onAddCategory = viewModel::addCategory,
            onSave = { id, title, amount, categoryId, date, note ->
                viewModel.saveExpense(id, title, amount, categoryId, date, note) { showEditor = false }
            },
        )
    }
}

@Composable
private fun ProfitSummaryCard(report: ir.factoryar.core.domain.model.ProfitReport) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
        ),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("سود و زیان این بازه", style = MaterialTheme.typography.titleSmall)
            AmountRow("درآمد فروش", report.revenue)
            AmountRow("بهای تمام‌شده کالا", -report.costOfGoodsSold)
            HorizontalDivider(Modifier.padding(vertical = 2.dp))
            AmountRow("سود ناخالص", report.grossProfit, bold = true)
            AmountRow("هزینه‌های عمومی", -report.operatingExpenses)
            HorizontalDivider(Modifier.padding(vertical = 2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "سود خالص",
                    Modifier.weight(1f),
                    style = MaterialTheme.typography.titleSmall,
                )
                MoneyText(
                    report.netProfit,
                    style = MaterialTheme.typography.titleMedium,
                    color = if (report.netProfit >= 0) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
            }
            if (report.revenue > 0) {
                Text(
                    "حاشیه سود خالص: ${PersianFormatter.formatQuantity(report.netMarginPercent)}٪",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun AmountRow(label: String, amount: Long, bold: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            Modifier.weight(1f),
            style = if (bold) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodySmall,
        )
        MoneyText(
            amount,
            style = if (bold) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodySmall,
            color = if (amount < 0) MaterialTheme.colorScheme.error else Color.Unspecified,
        )
    }
}

@Composable
private fun ExpenseRow(
    row: ir.factoryar.core.domain.model.ExpenseWithCategory,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    Column(Modifier.padding(horizontal = 16.dp)) {
        Row(
            Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(10.dp)
                    .background(Color(row.categoryColor), CircleShape),
            )
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    row.expense.title,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    buildString {
                        append(row.categoryName ?: "بدون دسته")
                        append(" • ")
                        append(JalaliConverter.fromEpochMillis(row.expense.date).format().toPersianDigits())
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            MoneyText(row.expense.amount, style = MaterialTheme.typography.bodyMedium)
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Filled.Delete,
                    contentDescription = "حذف",
                    tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f),
                )
            }
        }
        HorizontalDivider()
    }
}

@Composable
private fun ExpenseEditorDialog(
    initial: Expense?,
    categories: List<ir.factoryar.core.domain.model.ExpenseCategory>,
    onDismiss: () -> Unit,
    onAddCategory: (String) -> Unit,
    onSave: (id: Long, title: String, amount: String, categoryId: Long?, date: Long, note: String) -> Unit,
) {
    var title by remember { mutableStateOf(initial?.title.orEmpty()) }
    var amount by remember { mutableStateOf(initial?.amount?.takeIf { it > 0 }?.toString().orEmpty()) }
    var categoryId by remember { mutableStateOf(initial?.categoryId) }
    var date by remember { mutableStateOf(initial?.date?.takeIf { it > 0 } ?: DateUtils.now()) }
    var note by remember { mutableStateOf(initial?.note.orEmpty()) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showNewCategory by remember { mutableStateOf(false) }
    var newCategoryName by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "ثبت هزینه جدید" else "ویرایش هزینه") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("عنوان هزینه *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it },
                    label = { Text("مبلغ *") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                AssistChip(
                    onClick = { showDatePicker = true },
                    label = { Text(JalaliConverter.fromEpochMillis(date).format().toPersianDigits()) },
                    leadingIcon = { Icon(Icons.Filled.CalendarMonth, null) },
                )
                Text("دسته‌بندی", style = MaterialTheme.typography.labelMedium)
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(categories) { c ->
                        FilterChip(
                            selected = categoryId == c.id,
                            onClick = { categoryId = if (categoryId == c.id) null else c.id },
                            label = { Text(c.name, style = MaterialTheme.typography.labelSmall) },
                        )
                    }
                    item {
                        AssistChip(
                            onClick = { showNewCategory = true },
                            label = { Text("جدید") },
                            leadingIcon = { Icon(Icons.Filled.Add, null) },
                        )
                    }
                }
                if (showNewCategory) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = newCategoryName,
                            onValueChange = { newCategoryName = it },
                            label = { Text("نام دسته جدید") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = {
                            onAddCategory(newCategoryName)
                            newCategoryName = ""
                            showNewCategory = false
                        }) { Text("افزودن") }
                    }
                }
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("توضیحات") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onSave(initial?.id ?: 0L, title, amount, categoryId, date, note) },
                enabled = title.isNotBlank() && PersianFormatter.parseMoney(amount) > 0,
            ) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )

    if (showDatePicker) {
        JalaliDatePickerDialog(
            initialMillis = date,
            onDismiss = { showDatePicker = false },
            onConfirm = { date = it; showDatePicker = false },
            title = "تاریخ هزینه",
        )
    }
}
