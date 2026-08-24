package com.modir.forushgah.presentation.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Category
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.modir.forushgah.core.designsystem.component.EmptyState
import com.modir.forushgah.presentation.common.ProductRow
import com.modir.forushgah.presentation.common.SearchField

@Composable
fun ProductListRoute(
    onProductClick: (Long) -> Unit,
    onAddProduct: () -> Unit,
    onCategoriesClick: () -> Unit,
    viewModel: ProductListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    ProductListScreen(
        state = state,
        onQueryChange = viewModel::onQueryChange,
        onCategorySelected = viewModel::onCategorySelected,
        onProductClick = onProductClick,
        onAddProduct = onAddProduct,
        onCategoriesClick = onCategoriesClick,
    )
}

@Composable
fun ProductListScreen(
    state: ProductListUiState,
    onQueryChange: (String) -> Unit,
    onCategorySelected: (Long?) -> Unit,
    onProductClick: (Long) -> Unit,
    onAddProduct: () -> Unit,
    onCategoriesClick: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("محصولات") },
                actions = {
                    IconButton(onClick = onCategoriesClick) {
                        Icon(Icons.Filled.Category, contentDescription = "دسته‌بندی‌ها")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddProduct) {
                Icon(Icons.Filled.Add, contentDescription = "افزودن محصول")
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (state.isEmpty) {
                EmptyState(
                    title = "هنوز محصولی ثبت نکرده‌اید",
                    subtitle = "برای شروع، اولین محصولتان را اضافه کنید",
                    ctaLabel = "افزودن محصول",
                    onCtaClick = onAddProduct,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    SearchField(query = state.query, onQueryChange = onQueryChange, placeholder = "جستجوی محصول یا بارکد")

                    if (state.categories.isNotEmpty()) {
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            item {
                                FilterChip(
                                    selected = state.selectedCategoryId == null,
                                    onClick = { onCategorySelected(null) },
                                    label = { Text("همه") },
                                )
                            }
                            items(state.categories) { category ->
                                FilterChip(
                                    selected = state.selectedCategoryId == category.id,
                                    onClick = { onCategorySelected(category.id) },
                                    label = { Text("${category.name} (${category.productCount})") },
                                )
                            }
                        }
                    }

                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(state.products, key = { it.id }) { product ->
                            ProductRow(product = product, onClick = { onProductClick(product.id) })
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
