package com.forushyar.app.ui.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Save
import androidx.compose.material.icons.outlined.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.forushyar.app.BuildConfig
import com.forushyar.app.R
import kotlinx.coroutines.flow.collectLatest

@Composable
fun SettingsScreen(viewModel: SettingsViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var pendingBackup by remember { mutableStateOf<String?>(null) }
    var showImportWarning by remember { mutableStateOf(false) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        val content = pendingBackup
        pendingBackup = null
        if (uri != null && content != null) viewModel.writeExport(uri, content)
    }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> if (uri != null) viewModel.importBackup(uri) }

    val settingsSaved = stringResource(R.string.settings_saved)
    val exportSucceeded = stringResource(R.string.backup_export_succeeded)
    val importSucceeded = stringResource(R.string.backup_import_succeeded)
    val operationFailed = stringResource(R.string.backup_operation_failed)

    LaunchedEffect(viewModel) {
        viewModel.events.collectLatest { event ->
            when (event) {
                is SettingsEvent.BackupReady -> {
                    pendingBackup = event.content
                    exportLauncher.launch(event.fileName)
                }
                SettingsEvent.SettingsSaved -> snackbar.showSnackbar(settingsSaved)
                SettingsEvent.ExportSucceeded -> snackbar.showSnackbar(exportSucceeded)
                SettingsEvent.ImportSucceeded -> snackbar.showSnackbar(importSucceeded)
                SettingsEvent.OperationFailed -> snackbar.showSnackbar(operationFailed)
            }
        }
    }

    SettingsContent(
        state = state,
        snackbar = snackbar,
        onShopNameChange = viewModel::changeShopName,
        onConfirmDeletionChange = viewModel::changeDeleteConfirmation,
        onSave = viewModel::saveSettings,
        onExport = viewModel::prepareExport,
        onImport = { showImportWarning = true }
    )

    if (showImportWarning) {
        AlertDialog(
            onDismissRequest = { showImportWarning = false },
            title = { Text(stringResource(R.string.backup_import_warning_title)) },
            text = { Text(stringResource(R.string.backup_import_warning_text)) },
            confirmButton = {
                TextButton(onClick = {
                    showImportWarning = false
                    importLauncher.launch(arrayOf("application/json", "text/plain"))
                }) { Text(stringResource(R.string.continue_action)) }
            },
            dismissButton = {
                TextButton(onClick = { showImportWarning = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsContent(
    state: SettingsUiState,
    snackbar: SnackbarHostState,
    onShopNameChange: (String) -> Unit,
    onConfirmDeletionChange: (Boolean) -> Unit,
    onSave: () -> Unit,
    onExport: () -> Unit,
    onImport: () -> Unit
) {
    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.settings_title)) }) },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(stringResource(R.string.shop_settings), fontWeight = FontWeight.Bold)
            OutlinedTextField(
                value = state.shopName,
                onValueChange = onShopNameChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.shop_name)) },
                singleLine = true
            )
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(stringResource(R.string.confirm_deletion), fontWeight = FontWeight.Medium)
                        Text(
                            stringResource(R.string.confirm_deletion_hint),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(checked = state.confirmDeletion, onCheckedChange = onConfirmDeletionChange)
                }
            }
            Button(onClick = onSave, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Outlined.Save, contentDescription = null)
                Text(stringResource(R.string.save_settings), modifier = Modifier.padding(start = 8.dp))
            }

            Text(stringResource(R.string.backup_title), fontWeight = FontWeight.Bold)
            OutlinedButton(
                onClick = onExport,
                enabled = !state.isWorking,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Outlined.Upload, contentDescription = null)
                Text(stringResource(R.string.backup_export), modifier = Modifier.padding(start = 8.dp))
            }
            OutlinedButton(
                onClick = onImport,
                enabled = !state.isWorking,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Outlined.Download, contentDescription = null)
                Text(stringResource(R.string.backup_import), modifier = Modifier.padding(start = 8.dp))
            }
            if (state.isWorking) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
            }

            Text(stringResource(R.string.about_title), fontWeight = FontWeight.Bold)
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Column(modifier = Modifier.padding(start = 12.dp)) {
                        Text(stringResource(R.string.app_name), fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.app_version, BuildConfig.VERSION_NAME))
                        Text(
                            stringResource(R.string.about_description),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}
