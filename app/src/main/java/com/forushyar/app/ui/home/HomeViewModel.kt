package com.forushyar.app.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.repository.DashboardData
import com.forushyar.app.data.repository.DashboardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    dashboardRepository: DashboardRepository
) : ViewModel() {

    val uiState: StateFlow<DashboardData> = dashboardRepository
        .observeDashboard()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = DashboardData()
        )
}
