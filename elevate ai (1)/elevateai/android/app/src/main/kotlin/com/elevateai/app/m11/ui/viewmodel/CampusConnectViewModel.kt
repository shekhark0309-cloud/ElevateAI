package com.elevateai.app.m11.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elevateai.app.m11.data.models.DiscoveryStudent
import com.elevateai.app.m11.data.repository.CampusConnectRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class DiscoveryState {
    object Loading : DiscoveryState()
    data class Success(val students: List<DiscoveryStudent>) : DiscoveryState()
    data class Error(val message: String) : DiscoveryState()
}

class CampusConnectViewModel(
    private val repository: CampusConnectRepository,
    private val studentId: String
) : ViewModel() {

    private val _uiState = MutableStateFlow<DiscoveryState>(DiscoveryState.Loading)
    val uiState: StateFlow<DiscoveryState> = _uiState

    init {
        loadDiscovery()
        listenForRealtime()
    }

    fun loadDiscovery(filter: String = "all") {
        viewModelScope.launch {
            _uiState.value = DiscoveryState.Loading
            try {
                val feed = repository.getDiscoveryFeed(studentId, filter)
                _uiState.value = DiscoveryState.Success(feed)
            } catch (e: Exception) {
                _uiState.value = DiscoveryState.Error(e.message ?: "Failed to load discovery feed")
            }
        }
    }

    private fun listenForRealtime() {
        viewModelScope.launch {
            repository.observeConnectionRequests(studentId).collect {
                loadDiscovery()
            }
        }
    }

    fun connectWithStudent(targetId: String, type: String) {
        viewModelScope.launch {
            try {
                repository.manageConnection(targetId, "request", type)
                loadDiscovery()
            } catch (e: Exception) {
                // Handle error
            }
        }
    }
}
