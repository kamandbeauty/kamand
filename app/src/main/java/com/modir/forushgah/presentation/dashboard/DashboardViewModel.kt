package com.modir.forushgah.presentation.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.DashboardRepository
import com.modir.forushgah.domain.model.DashboardSnapshot
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

sealed interface DashboardUiState {
    data object Loading : DashboardUiState
    data class Content(val snapshot: DashboardSnapshot) : DashboardUiState
    data class Error(val message: String) : DashboardUiState
}

@HiltViewModel
class DashboardViewModel @Inject constructor(
    dashboardRepository: DashboardRepository,
) : ViewModel() {

    val uiState: StateFlow<DashboardUiState> = dashboardRepository.observeSnapshot()
        .map<DashboardSnapshot, DashboardUiState> { DashboardUiState.Content(it) }
        .onStart { emit(DashboardUiState.Loading) }
        .catch { emit(DashboardUiState.Error(it.message ?: "خطای غیرمنتظره")) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = DashboardUiState.Loading,
        )
}
