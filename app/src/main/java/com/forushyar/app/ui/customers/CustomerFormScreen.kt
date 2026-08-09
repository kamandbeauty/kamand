package com.forushyar.app.ui.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.forushyar.app.R
import kotlinx.coroutines.flow.collectLatest

@Composable
fun CustomerFormScreen(
    onBack: () -> Unit,
    viewModel: CustomerFormViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveError = stringResource(R.string.customer_save_error)

    LaunchedEffect(viewModel) {
        viewModel.events.collectLatest { event ->
            when (event) {
                CustomerFormEvent.Saved -> onBack()
                CustomerFormEvent.SaveFailed -> snackbarHostState.showSnackbar(saveError)
            }
        }
    }

    CustomerFormContent(
        state = state,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onNameChange = viewModel::onNameChange,
        onPhoneChange = viewModel::onPhoneChange,
        onInstagramIdChange = viewModel::onInstagramIdChange,
        onAddressChange = viewModel::onAddressChange,
        onNoteChange = viewModel::onNoteChange,
        onSave = viewModel::save
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CustomerFormContent(
    state: CustomerFormState,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onNameChange: (String) -> Unit,
    onPhoneChange: (String) -> Unit,
    onInstagramIdChange: (String) -> Unit,
    onAddressChange: (String) -> Unit,
    onNoteChange: (String) -> Unit,
    onSave: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(stringResource(if (state.id == 0L) R.string.add_customer else R.string.edit_customer))
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
            state.isLoading -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            state.loadFailed -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(paddingValues).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(stringResource(R.string.customer_not_found))
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
                        label = { Text(stringResource(R.string.customer_name)) },
                        supportingText = if (state.nameError) {
                            { Text(stringResource(R.string.customer_name_required)) }
                        } else null,
                        isError = state.nameError,
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                    )
                    OutlinedTextField(
                        value = state.phone,
                        onValueChange = onPhoneChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.customer_phone_optional)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Phone,
                            imeAction = ImeAction.Next
                        )
                    )
                    OutlinedTextField(
                        value = state.instagramId,
                        onValueChange = onInstagramIdChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.customer_instagram_optional)) },
                        prefix = { Text("@") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                    )
                    OutlinedTextField(
                        value = state.address,
                        onValueChange = onAddressChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.customer_address_optional)) },
                        minLines = 2,
                        maxLines = 4
                    )
                    OutlinedTextField(
                        value = state.note,
                        onValueChange = onNoteChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.customer_note_optional)) },
                        minLines = 2,
                        maxLines = 4
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
                        Text(stringResource(R.string.save_customer))
                    }
                }
            }
        }
    }
}
