package com.forushyar.app.ui.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.forushyar.app.R
import kotlinx.coroutines.flow.collectLatest

@Composable
fun ProductFormScreen(
    onBack: () -> Unit,
    viewModel: ProductFormViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveError = stringResource(R.string.product_save_error)

    LaunchedEffect(viewModel) {
        viewModel.events.collectLatest { event ->
            when (event) {
                ProductFormEvent.Saved -> onBack()
                ProductFormEvent.SaveFailed -> snackbarHostState.showSnackbar(saveError)
            }
        }
    }

    ProductFormContent(
        state = state,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onCategoryChange = viewModel::onCategoryChange,
        onBuyPriceChange = viewModel::onBuyPriceChange,
        onSellPriceChange = viewModel::onSellPriceChange,
        onStockChange = viewModel::onStockChange,
        onSave = viewModel::save
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProductFormContent(
    state: ProductFormState,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onCategoryChange: (String) -> Unit,
    onBuyPriceChange: (String) -> Unit,
    onSellPriceChange: (String) -> Unit,
    onStockChange: (String) -> Unit,
    onSave: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(stringResource(if (state.id == 0L) R.string.add_product else R.string.edit_product))
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        when {
            state.isLoading -> LoadingProduct(modifier = Modifier.padding(paddingValues))
            state.loadFailed -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(paddingValues).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(stringResource(R.string.product_not_found))
                    Button(onClick = onBack, modifier = Modifier.padding(top = 16.dp)) {
                        Text(stringResource(R.string.back))
                    }
                }
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedTextField(
                        value = state.name,
                        onValueChange = onNameChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.product_name)) },
                        supportingText = if (state.nameError) {
                            { Text(stringResource(R.string.product_name_required)) }
                        } else null,
                        isError = state.nameError,
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                    )
                    OutlinedTextField(
                        value = state.category,
                        onValueChange = onCategoryChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.product_category_optional)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                    )
                    NumberField(
                        value = state.buyPrice,
                        onValueChange = onBuyPriceChange,
                        label = stringResource(R.string.product_buy_price),
                        error = state.buyPriceError,
                        errorText = stringResource(R.string.valid_price_required),
                        suffix = stringResource(R.string.currency_toman)
                    )
                    NumberField(
                        value = state.sellPrice,
                        onValueChange = onSellPriceChange,
                        label = stringResource(R.string.product_sell_price),
                        error = state.sellPriceError,
                        errorText = stringResource(R.string.valid_price_required),
                        suffix = stringResource(R.string.currency_toman)
                    )
                    NumberField(
                        value = state.stock,
                        onValueChange = onStockChange,
                        label = stringResource(R.string.product_stock),
                        error = state.stockError,
                        errorText = stringResource(R.string.valid_stock_required),
                        imeAction = ImeAction.Done
                    )
                    Button(
                        onClick = onSave,
                        enabled = !state.isSaving,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) {
                        if (state.isSaving) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp).padding(end = 4.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary
                            )
                        } else {
                            Icon(Icons.Default.Save, contentDescription = null, modifier = Modifier.padding(end = 8.dp))
                        }
                        Text(stringResource(R.string.save_product))
                    }
                }
            }
        }
    }
}

@Composable
private fun NumberField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    error: Boolean,
    errorText: String,
    suffix: String? = null,
    imeAction: ImeAction = ImeAction.Next
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier.fillMaxWidth(),
        label = { Text(label) },
        suffix = suffix?.let { { Text(it) } },
        supportingText = if (error) { { Text(errorText) } } else null,
        isError = error,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = imeAction)
    )
}

@Composable
private fun LoadingProduct(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator()
    }
}
