package com.elevateai.app.m2.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m2.data.models.*
import com.elevateai.app.m2.data.repository.TeamRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class TeamFinderState {
    object Loading : TeamFinderState()
    data class Success(
        val matches: List<TeamMatch>,
        val nearby: List<NearbyTeammate>
    ) : TeamFinderState()
    data class Error(val message: String) : TeamFinderState()
}

class TeamFinderViewModel(
    private val repository: TeamRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<TeamFinderState>(TeamFinderState.Loading)
    val uiState: StateFlow<TeamFinderState> = _uiState

    init {
        loadTeams()
    }

    fun loadTeams() {
        viewModelScope.launch {
            _uiState.value = TeamFinderState.Loading
            try {
                val matches = repository.getTeamMatches(studentId)
                val nearby = repository.getNearbyTeammates(studentId)
                _uiState.value = TeamFinderState.Success(matches, nearby)
            } catch (e: Exception) {
                _uiState.value = TeamFinderState.Error(e.message ?: "Failed to load teams")
            }
        }
    }

    fun updateStatus(newStatus: String) {
        viewModelScope.launch {
            try {
                repository.updateAvailability(studentId, newStatus)
                // Realtime or manual refresh
            } catch (e: Exception) {
                // handle error
            }
        }
    }
}
