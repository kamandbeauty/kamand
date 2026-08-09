package com.forushyar.app.ui.settings

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.repository.BackupRepository
import com.forushyar.app.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class SettingsUiState(
    val shopName: String = "",
    val confirmDeletion: Boolean = true,
    val isWorking: Boolean = false
)

sealed interface SettingsEvent {
    data class BackupReady(val fileName: String, val content: String) : SettingsEvent
    data object SettingsSaved : SettingsEvent
    data object ExportSucceeded : SettingsEvent
    data object ImportSucceeded : SettingsEvent
    data object OperationFailed : SettingsEvent
}

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val backupRepository: BackupRepository
) : ViewModel() {
    private val _state = MutableStateFlow(
        SettingsUiState(
            shopName = settingsRepository.settings.value.shopName,
            confirmDeletion = settingsRepository.settings.value.confirmDeletion
        )
    )
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    private val _events = Channel<SettingsEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    fun changeShopName(value: String) { _state.value = _state.value.copy(shopName = value) }

    fun changeDeleteConfirmation(value: Boolean) {
        settingsRepository.setConfirmDeletion(value)
        _state.value = _state.value.copy(confirmDeletion = value)
    }

    fun saveSettings() {
        settingsRepository.setShopName(_state.value.shopName)
        _state.value = _state.value.copy(shopName = settingsRepository.settings.value.shopName)
        viewModelScope.launch { _events.send(SettingsEvent.SettingsSaved) }
    }

    fun prepareExport() = runOperation {
        val content = backupRepository.exportJson()
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        _events.send(SettingsEvent.BackupReady("ForushYar_Backup_$date.json", content))
    }

    fun writeExport(uri: Uri, content: String) = runOperation {
        withContext(Dispatchers.IO) {
            context.contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use { it.write(content) }
                ?: error("cannot_open_output")
        }
        _events.send(SettingsEvent.ExportSucceeded)
    }

    fun importBackup(uri: Uri) = runOperation {
        val content = withContext(Dispatchers.IO) {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                ?: error("cannot_open_input")
        }
        require(content.length <= MAX_BACKUP_CHARACTERS) { "backup_too_large" }
        backupRepository.importJson(content)
        val restored = settingsRepository.settings.value
        _state.value = _state.value.copy(
            shopName = restored.shopName,
            confirmDeletion = restored.confirmDeletion
        )
        _events.send(SettingsEvent.ImportSucceeded)
    }

    private fun runOperation(block: suspend () -> Unit) {
        if (_state.value.isWorking) return
        viewModelScope.launch {
            _state.value = _state.value.copy(isWorking = true)
            runCatching { block() }
                .onFailure { _events.send(SettingsEvent.OperationFailed) }
            _state.value = _state.value.copy(isWorking = false)
        }
    }

    private companion object {
        const val MAX_BACKUP_CHARACTERS = 20_000_000
    }
}
