package com.elevateai.app.dashboard.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.dashboard.data.models.OSDashboardData
import com.elevateai.app.dashboard.data.repository.DashboardRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class DashboardState {
    object Loading : DashboardState()
    data class Success(val data: OSDashboardData) : DashboardState()
    data class Error(val message: String) : DashboardState()
}

class OSDashboardViewModel(
    private val repository: DashboardRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<DashboardState>(DashboardState.Loading)
    val uiState: StateFlow<DashboardState> = _uiState

    init {
        loadDashboard()
        listenForRealtime()
    }

    fun loadDashboard() {
        viewModelScope.launch {
            _uiState.value = DashboardState.Loading
            try {
                val data = repository.getOSDashboard(studentId)
                _uiState.value = DashboardState.Success(data)
            } catch (e: Exception) {
                _uiState.value = DashboardState.Error(e.message ?: "Failed to load dashboard")
            }
        }
    }

    private fun listenForRealtime() {
        viewModelScope.launch {
            repository.observeDashboardSignals(studentId).collect {
                // Refresh dashboard data silently when signals change
                loadDashboardSilently()
            }
        }
        viewModelScope.launch {
            repository.observeDnaChanges(studentId).collect {
                loadDashboard() // Full reload for DNA archetype shifts
            }
        }
    }

    private fun loadDashboardSilently() {
        viewModelScope.launch {
            try {
                val data = repository.getOSDashboard(studentId)
                _uiState.value = DashboardState.Success(data)
            } catch (e: Exception) { /* ignore silent error */ }
        }
    }
}
