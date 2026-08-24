package com.modir.forushgah.presentation.categories

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.common.PersianNumberFormatter
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.domain.model.Category

@Composable
fun CategoryListRoute(
    onBack: () -> Unit,
    viewModel: CategoryListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()

    var showAddDialog by remember { mutableStateOf(false) }
    var renamingCategory by remember { mutableStateOf<Category?>(null) }
    var archivingCategory by remember { mutableStateOf<Category?>(null) }

    CategoryListScreen(
        state = state,
        showAddDialog = showAddDialog,
        renamingCategory = renamingCategory,
        archivingCategory = archivingCategory,
        onBack = onBack,
        onAddClick = { showAddDialog = true },
        onCategoryClick = { renamingCategory = it },
        onArchiveClick = { archivingCategory = it },
        onAddName = { name ->
            viewModel.add(name)
            showAddDialog = false
        },
        onAddDismiss = { showAddDialog = false },
        onRenameName = { name ->
            renamingCategory?.let { viewModel.rename(it, name) }
            renamingCategory = null
        },
        onRenameDismiss = { renamingCategory = null },
        onArchiveConfirm = {
            archivingCategory?.let { viewModel.archive(it.id) }
            archivingCategory = null
        },
        onArchiveDismiss = { archivingCategory = null },
    )
}

@Composable
fun CategoryListScreen(
    state: CategoryListUiState,
    showAddDialog: Boolean,
    renamingCategory: Category?,
    archivingCategory: Category?,
    onBack: () -> Unit,
    onAddClick: () -> Unit,
    onCategoryClick: (Category) -> Unit,
    onArchiveClick: (Category) -> Unit,
    onAddName: (String) -> Unit,
    onAddDismiss: () -> Unit,
    onRenameName: (String) -> Unit,
    onRenameDismiss: () -> Unit,
    onArchiveConfirm: () -> Unit,
    onArchiveDismiss: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("دسته‌بندی‌ها") },
                navigationIcon = { TextButton(onClick = onBack) { Text("بازگشت") } },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddClick) {
                Icon(Icons.Filled.Add, contentDescription = "افزودن دسته‌بندی")
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (!state.isLoading && state.categories.isEmpty()) {
                EmptyState(
                    title = "هنوز دسته‌بندی ندارید",
                    subtitle = "محصول‌ها را با دسته‌بندی سازمان‌دهی کنید تا فیلتر کردن آسان‌تر شود",
                    ctaLabel = "افزودن دسته‌بندی",
                    onCtaClick = onAddClick,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.categories, key = { it.id }) { category ->
                        CategoryRow(
                            category = category,
                            onClick = { onCategoryClick(category) },
                            onArchiveClick = { onArchiveClick(category) },
                        )
                    }
                }
            }
        }
    }

    if (showAddDialog) {
        NameEntryDialog(
            title = "دسته‌بندی جدید",
            confirmLabel = "افزودن",
            onConfirm = onAddName,
            onDismiss = onAddDismiss,
        )
    }
    if (renamingCategory != null) {
        NameEntryDialog(
            title = "ویرایش دسته‌بندی",
            confirmLabel = "ذخیره",
            initialName = renamingCategory!!.name,
            onConfirm = onRenameName,
            onDismiss = onRenameDismiss,
        )
    }
    if (archivingCategory != null) {
        AlertDialog(
            onDismissRequest = onArchiveDismiss,
            title = { Text("بایگانی دسته‌بندی") },
            text = {
                Text(
                    "«${archivingCategory!!.name}» بایگانی می‌شود و از فهرست دسته‌بندی‌ها حذف می‌گردد. " +
                        "محصول‌های این دسته باقی می‌مانند اما بدون دسته نمایش داده می‌شوند.",
                )
            },
            confirmButton = { TextButton(onClick = onArchiveConfirm) { Text("بایگانی") } },
            dismissButton = { TextButton(onClick = onArchiveDismiss) { Text("انصراف") } },
        )
    }
}

@Composable
private fun CategoryRow(category: Category, onClick: () -> Unit, onArchiveClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f).padding(vertical = 4.dp)) {
                Text(category.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    "${PersianNumberFormatter.toPersianDigits(category.productCount.toString())} محصول",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            IconButton(onClick = onArchiveClick) {
                Icon(
                    Icons.Filled.DeleteOutline,
                    contentDescription = "بایگانی دسته‌بندی",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun NameEntryDialog(
    title: String,
    confirmLabel: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
    initialName: String = "",
) {
    var name by remember { mutableStateOf(initialName) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("نام دسته‌بندی") },
                singleLine = true,
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(name) }, enabled = name.isNotBlank()) {
                Text(confirmLabel)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
